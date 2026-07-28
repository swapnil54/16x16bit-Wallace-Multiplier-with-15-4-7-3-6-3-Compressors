#!/usr/bin/env python3
"""
verify_wallace_exhaustive.py -- independent verification of the 16x16 Wallace
multiplier with no HDL simulator required.

Comments in the Verilog are stripped before parsing and influence nothing.

  python3 verify_wallace_exhaustive.py <dir>                     # audit + leaves + quick sim
  python3 verify_wallace_exhaustive.py <dir> --exhaustive        # all 2^32 operand pairs
  python3 verify_wallace_exhaustive.py <dir> --exhaustive 0 16384  # one chunk

What it establishes
  1. every leaf (HA, FA, 5:3, 6:3, 7:3, 15:4) emits the exact popcount of its
     inputs, over ALL 2^k input patterns;
  2. the top level is structurally sound -- 256 correct partial products, one
     driver per net, at most one consumer per net, every counter fed from a
     single column, A[i] and B[i] carrying weight exactly i;
  3. (1) and (2) together are an algebraic proof that A + B == a*b for every
     input, with the single discarded weight-32 bit provably zero;
  4. --exhaustive additionally simulates the flattened gate netlist against an
     independent shift-and-add reference over all 4,294,967,296 operand pairs.
"""
import re
from collections import OrderedDict, defaultdict

# --------------------------------------------------------------------------
# lexing helpers
# --------------------------------------------------------------------------

def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    text = re.sub(r'//[^\n]*', ' ', text)
    return text


def strip_directives(text):
    # `default_nettype none / `timescale ... — whole line
    return re.sub(r'^\s*`[^\n]*$', ' ', text, flags=re.M)


def split_top_level(s, sep):
    """split on `sep` at paren/brace/bracket depth 0"""
    out, depth, cur = [], 0, []
    for ch in s:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == sep and depth == 0:
            out.append(''.join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append(''.join(cur))
    return out


# --------------------------------------------------------------------------
# expression AST
# --------------------------------------------------------------------------

TOKEN_RE = re.compile(r"""
      (?P<num>\d+\s*'\s*[bBhHdDoO]\s*[0-9a-fA-FxXzZ_]+ | \d+)
    | (?P<id>[A-Za-z_][A-Za-z0-9_$]*)
    | (?P<op>[&|^~+\-*(){}\[\]:,])
    | (?P<ws>\s+)
""", re.X)


def tokenize(expr):
    toks, pos = [], 0
    while pos < len(expr):
        m = TOKEN_RE.match(expr, pos)
        if not m:
            raise SyntaxError("bad token at %r" % expr[pos:pos + 30])
        pos = m.end()
        if m.lastgroup == 'ws':
            continue
        toks.append((m.lastgroup, m.group().strip()))
    return toks


class P:
    """recursive-descent expression parser -> nested tuples"""

    def __init__(self, toks):
        self.t = toks
        self.i = 0

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else (None, None)

    def eat(self, val=None):
        k, v = self.peek()
        if val is not None and v != val:
            raise SyntaxError("expected %r got %r" % (val, v))
        self.i += 1
        return v

    # precedence (low -> high): | , ^ , & , + , unary ~ , primary
    def parse(self):
        return self.p_or()

    def p_or(self):
        n = self.p_xor()
        while self.peek()[1] == '|':
            self.eat(); n = ('or', n, self.p_xor())
        return n

    def p_xor(self):
        n = self.p_and()
        while self.peek()[1] == '^':
            self.eat(); n = ('xor', n, self.p_and())
        return n

    def p_and(self):
        n = self.p_add()
        while self.peek()[1] == '&':
            self.eat(); n = ('and', n, self.p_add())
        return n

    def p_add(self):
        n = self.p_unary()
        while self.peek()[1] == '+':
            self.eat(); n = ('add', n, self.p_unary())
        return n

    def p_unary(self):
        if self.peek()[1] == '~':
            self.eat(); return ('not', self.p_unary())
        return self.p_primary()

    def p_primary(self):
        k, v = self.peek()
        if v == '(':
            self.eat(); n = self.parse(); self.eat(')'); return n
        if v == '{':
            self.eat()
            parts = [self.parse()]
            while self.peek()[1] == ',':
                self.eat(); parts.append(self.parse())
            self.eat('}')
            return ('concat', parts)
        if k == 'num':
            self.eat()
            return ('const', v)
        if k == 'id':
            name = self.eat()
            if self.peek()[1] == '[':
                self.eat()
                a = self.parse()
                if self.peek()[1] == ':':
                    self.eat(); b = self.parse(); self.eat(']')
                    return ('part', name, a, b)
                self.eat(']')
                return ('bit', name, a)
            return ('id', name)
        raise SyntaxError("unexpected token %r" % (v,))


def parse_expr(s):
    return P(tokenize(s)).parse()


def const_int(node):
    """evaluate a constant expression (index arithmetic / literals)"""
    t = node[0]
    if t == 'const':
        v = node[1].replace(' ', '')
        if "'" in v:
            w, rest = v.split("'")
            base, digits = rest[0].lower(), rest[1:].replace('_', '')
            b = {'b': 2, 'o': 8, 'd': 10, 'h': 16}[base]
            return int(digits, b), int(w)
        return int(v), 32
    if t == 'add':
        return const_int(node[1])[0] + const_int(node[2])[0], 32
    raise ValueError("not constant: %r" % (node,))


# --------------------------------------------------------------------------
# module description
# --------------------------------------------------------------------------

class Port:
    def __init__(self, name, direction, msb, lsb):
        self.name, self.dir, self.msb, self.lsb = name, direction, msb, lsb

    @property
    def width(self):
        return abs(self.msb - self.lsb) + 1


class Module:
    def __init__(self, name):
        self.name = name
        self.ports = OrderedDict()      # name -> Port
        self.wires = OrderedDict()      # name -> (msb, lsb)
        self.assigns = []               # (lhs_str, rhs_str)
        self.insts = []                 # (modname, instname, conns)
        self.always = []                # raw text (unsupported / informational)


RANGE_RE = re.compile(r'\[\s*([^\]:]+)\s*:\s*([^\]]+)\s*\]')


def parse_range(txt):
    m = RANGE_RE.search(txt)
    if not m:
        return 0, 0
    return const_int(parse_expr(m.group(1)))[0], const_int(parse_expr(m.group(2)))[0]


def parse_modules(text):
    text = strip_directives(strip_comments(text))
    mods = OrderedDict()
    for m in re.finditer(r'\bmodule\b(.*?)\bendmodule\b', text, flags=re.S):
        body_all = m.group(1)
        # header: name ( portlist ) ;
        hm = re.match(r'\s*([A-Za-z_]\w*)\s*(\((.*?)\))?\s*;', body_all, flags=re.S)
        name = hm.group(1)
        portlist = hm.group(3) or ''
        body = body_all[hm.end():]
        mod = Module(name)
        # ANSI port list
        cur_dir, cur_rng = None, (0, 0)
        for item in split_top_level(portlist, ','):
            item = item.strip()
            if not item:
                continue
            dm = re.match(r'\b(input|output|inout)\b', item)
            if dm:
                cur_dir = dm.group(1)
                item = item[dm.end():].strip()
            item = re.sub(r'^\s*(wire|reg)\b', '', item).strip()
            rm = RANGE_RE.match(item)
            if rm:
                cur_rng = parse_range(rm.group(0))
                item = item[rm.end():].strip()
            else:
                cur_rng = (0, 0)
            pname = item.strip()
            assert re.fullmatch(r'\w+', pname), (name, item)
            mod.ports[pname] = Port(pname, cur_dir, cur_rng[0], cur_rng[1])

        # body statements
        # pull out always blocks first (only in the wrapper)
        for am in re.finditer(r'\balways\b.*?\bend\b', body, flags=re.S):
            mod.always.append(am.group(0))
        body = re.sub(r'\balways\b.*?\bend\b', ' ', body, flags=re.S)

        for stmt in split_top_level(body, ';'):
            s = stmt.strip()
            if not s:
                continue
            if s.startswith('assign'):
                lhs, rhs = split_top_level(s[len('assign'):], '=')
                mod.assigns.append((lhs.strip(), rhs.strip()))
                continue
            if re.match(r'\b(wire|reg)\b', s):
                s2 = re.sub(r'^\s*(wire|reg)\b', '', s).strip()
                rng = (0, 0)
                rm = RANGE_RE.match(s2)
                if rm:
                    rng = parse_range(rm.group(0))
                    s2 = s2[rm.end():].strip()
                for decl in split_top_level(s2, ','):
                    decl = decl.strip()
                    if not decl:
                        continue
                    if '=' in decl:
                        dn, dv = split_top_level(decl, '=')
                        dn = dn.strip()
                        mod.wires[dn] = rng
                        mod.assigns.append((dn, dv.strip()))
                    else:
                        mod.wires[decl] = rng
                continue
            # instantiation:  Type name ( conns )
            im = re.match(r'([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*\((.*)\)\s*$',
                          s, flags=re.S)
            if im:
                mtype, iname, conns = im.group(1), im.group(2), im.group(3)
                items = [c.strip() for c in split_top_level(conns, ',')]
                parsed = []
                for c in items:
                    cm = re.match(r'\.\s*(\w+)\s*\((.*)\)\s*$', c, flags=re.S)
                    if cm:
                        parsed.append((cm.group(1), cm.group(2).strip()))
                    else:
                        parsed.append((None, c))
                mod.insts.append((mtype, iname, parsed))
                continue
            raise SyntaxError("unparsed statement in %s: %r" % (name, s[:80]))
        mods[name] = mod
    return mods


# --------------------------------------------------------------------------
# elaboration into a flat bit-level gate netlist
# --------------------------------------------------------------------------

class Netlist:
    def __init__(self):
        self.gates = []               # (op, out, ins...)   op in and/or/xor/not/buf
        self.n = 0
        self.const0 = self.new('const0')
        self.const1 = self.new('const1')
        self.names = {}

    def new(self, hint=''):
        i = self.n
        self.n += 1
        return i


class Elaborator:
    def __init__(self, mods):
        self.mods = mods
        self.nl = Netlist()
        self.drivers = defaultdict(list)     # flat signal path -> list of driver descriptions
        self.loads = defaultdict(list)
        self.issues = []

    # -- signal storage: map (scope, name, index) -> net id
    def sig(self, env, scope, name, idx):
        key = (scope, name, idx)
        if key in env:
            return env[key]
        nid = self.nl.new()
        env[key] = nid
        return nid

    def widths(self, mod, name):
        if name in mod.ports:
            p = mod.ports[name]
            return p.msb, p.lsb
        if name in mod.wires:
            return mod.wires[name]
        return None

    # -- evaluate an expression node -> list of net ids, LSB first
    def eval_expr(self, node, mod, scope, env, port_map):
        t = node[0]
        if t == 'id':
            nm = node[1]
            if nm in port_map:
                return list(port_map[nm])
            rng = self.widths(mod, nm)
            if rng is None:
                self.issues.append("UNDECLARED identifier %r in %s" % (nm, mod.name))
                rng = (0, 0)
            msb, lsb = rng
            lo, hi = min(msb, lsb), max(msb, lsb)
            return [self.sig(env, scope, nm, i) for i in range(lo, hi + 1)]
        if t == 'bit':
            nm, idx = node[1], const_int(node[2])[0]
            if nm in port_map:
                return [port_map[nm][idx]]
            rng = self.widths(mod, nm)
            if rng is None:
                self.issues.append("UNDECLARED identifier %r in %s" % (nm, mod.name))
            else:
                lo, hi = min(rng), max(rng)
                if not (lo <= idx <= hi):
                    self.issues.append("INDEX OUT OF RANGE %s[%d] in %s" % (nm, idx, mod.name))
            return [self.sig(env, scope, nm, idx)]
        if t == 'part':
            nm = node[1]
            a, b = const_int(node[2])[0], const_int(node[3])[0]
            lo, hi = min(a, b), max(a, b)
            if nm in port_map:
                return [port_map[nm][i] for i in range(lo, hi + 1)]
            return [self.sig(env, scope, nm, i) for i in range(lo, hi + 1)]
        if t == 'concat':
            bits = []
            for p in reversed(node[1]):          # rightmost = LSB
                bits.extend(self.eval_expr(p, mod, scope, env, port_map))
            return bits
        if t == 'const':
            val, w = const_int(node)
            return [self.nl.const1 if (val >> i) & 1 else self.nl.const0
                    for i in range(w)]
        if t in ('and', 'or', 'xor'):
            x = self.eval_expr(node[1], mod, scope, env, port_map)
            y = self.eval_expr(node[2], mod, scope, env, port_map)
            w = max(len(x), len(y))
            x = x + [self.nl.const0] * (w - len(x))
            y = y + [self.nl.const0] * (w - len(y))
            out = []
            for i in range(w):
                o = self.nl.new()
                self.nl.gates.append((t, o, x[i], y[i]))
                out.append(o)
            return out
        if t == 'not':
            x = self.eval_expr(node[1], mod, scope, env, port_map)
            out = []
            for b in x:
                o = self.nl.new()
                self.nl.gates.append(('not', o, b))
                out.append(o)
            return out
        if t == 'add':
            x = self.eval_expr(node[1], mod, scope, env, port_map)
            y = self.eval_expr(node[2], mod, scope, env, port_map)
            w = max(len(x), len(y))
            x = x + [self.nl.const0] * (w - len(x))
            y = y + [self.nl.const0] * (w - len(y))
            carry = self.nl.const0
            out = []
            for i in range(w):
                s1 = self.nl.new(); self.nl.gates.append(('xor', s1, x[i], y[i]))
                s = self.nl.new();  self.nl.gates.append(('xor', s, s1, carry))
                g = self.nl.new();  self.nl.gates.append(('and', g, x[i], y[i]))
                p = self.nl.new();  self.nl.gates.append(('and', p, s1, carry))
                c = self.nl.new();  self.nl.gates.append(('or', c, g, p))
                out.append(s); carry = c
            return out
        raise ValueError("cannot evaluate %r" % (t,))

    def lhs_bits(self, lhs, mod, scope, env, port_map):
        return self.eval_expr(parse_expr(lhs), mod, scope, env, port_map)

    def elaborate(self, modname, scope, port_map, env=None):
        """port_map: portname -> list of net ids (LSB first) supplied by parent"""
        mod = self.mods[modname]
        if env is None:
            env = {}
        # continuous assignments
        for lhs, rhs in mod.assigns:
            lb = self.lhs_bits(lhs, mod, scope, env, port_map)
            rb = self.eval_expr(parse_expr(rhs), mod, scope, env, port_map)
            rb = rb + [self.nl.const0] * (len(lb) - len(rb))
            for i, dst in enumerate(lb):
                self.nl.gates.append(('buf', dst, rb[i]))
                self.drivers[dst].append((scope, lhs, i))
        # instances
        for mtype, iname, conns in mod.insts:
            sub = self.mods[mtype]
            sub_map = {}
            named = conns[0][0] is not None
            if named:
                seen = set()
                for pn, expr in conns:
                    if pn not in sub.ports:
                        self.issues.append("PORT %s.%s does not exist (inst %s/%s)"
                                           % (mtype, pn, scope, iname))
                        continue
                    if pn in seen:
                        self.issues.append("PORT %s connected twice in %s/%s" % (pn, scope, iname))
                    seen.add(pn)
                    p = sub.ports[pn]
                    bits = self.eval_expr(parse_expr(expr), mod, scope, env, port_map)
                    if len(bits) != p.width:
                        self.issues.append(
                            "WIDTH MISMATCH %s/%s.%s : port=%d expr=%d (%s)"
                            % (scope, iname, pn, p.width, len(bits), expr))
                    if len(bits) < p.width:
                        bits = bits + [self.nl.const0] * (p.width - len(bits))
                    sub_map[pn] = bits[:p.width]
                missing = [p for p in sub.ports if p not in seen]
                if missing:
                    self.issues.append("UNCONNECTED PORTS %s in %s/%s" % (missing, scope, iname))
                    for p in missing:
                        sub_map[p] = [self.nl.new() for _ in range(sub.ports[p].width)]
            else:
                plist = list(sub.ports.values())
                if len(conns) != len(plist):
                    self.issues.append("ARITY MISMATCH %s/%s: %d vs %d"
                                       % (scope, iname, len(conns), len(plist)))
                for p, (_, expr) in zip(plist, conns):
                    bits = self.eval_expr(parse_expr(expr), mod, scope, env, port_map)
                    if len(bits) != p.width:
                        self.issues.append(
                            "WIDTH MISMATCH %s/%s.%s : port=%d expr=%d (%s)"
                            % (scope, iname, p.name, p.width, len(bits), expr))
                    if len(bits) < p.width:
                        bits = bits + [self.nl.const0] * (p.width - len(bits))
                    sub_map[p.name] = bits[:p.width]
            self.elaborate(mtype, scope + '/' + iname, sub_map)
        return env


# --------------------------------------------------------------------------
# bit-parallel evaluation
# --------------------------------------------------------------------------

def topo_order(gates, n):
    """return gate evaluation order; raises on combinational loop"""
    produced_by = {}
    for gi, g in enumerate(gates):
        out = g[1]
        if out in produced_by:
            raise ValueError("MULTIPLE DRIVERS on net %d" % out)
        produced_by[out] = gi
    indeg = [0] * len(gates)
    fanout = defaultdict(list)
    for gi, g in enumerate(gates):
        for inp in g[2:]:
            if inp in produced_by:
                indeg[gi] += 1
                fanout[produced_by[inp]].append(gi)
    order, stack = [], [i for i in range(len(gates)) if indeg[i] == 0]
    while stack:
        gi = stack.pop()
        order.append(gi)
        for nxt in fanout[gi]:
            indeg[nxt] -= 1
            if indeg[nxt] == 0:
                stack.append(nxt)
    if len(order) != len(gates):
        raise ValueError("COMBINATIONAL LOOP detected (%d/%d ordered)"
                         % (len(order), len(gates)))
    return order


def simulate(gates, order, nnets, const0, const1, drive, mask):
    v = [0] * nnets
    v[const1] = mask
    for net, val in drive.items():
        v[net] = val
    for gi in order:
        g = gates[gi]
        op = g[0]
        if op == 'and':
            v[g[1]] = v[g[2]] & v[g[3]]
        elif op == 'or':
            v[g[1]] = v[g[2]] | v[g[3]]
        elif op == 'xor':
            v[g[1]] = v[g[2]] ^ v[g[3]]
        elif op == 'not':
            v[g[1]] = (~v[g[2]]) & mask
        elif op == 'buf':
            v[g[1]] = v[g[2]]
    return v


def logic_depth(gates, order, inputs):
    d = defaultdict(int)
    for net in inputs:
        d[net] = 0
    for gi in order:
        g = gates[gi]
        cost = 0 if g[0] == 'buf' else 1
        d[g[1]] = max(d[i] for i in g[2:]) + cost
    return d


# ==========================================================================
#  verification driver
# ==========================================================================
import os, re, time
from collections import Counter, defaultdict

OUTOFF = {
    'half_adder':     {'s': 0, 'c': 1},
    'full_adder':     {'s': 0, 'cout': 1},
    'compressor_6_3': {'S': 0, 'C1': 1, 'C2': 2},
    'compressor_7_3': {'S': 0, 'C1': 1, 'C2': 2},
    'counter_15_4':   {'O0': 0, 'O1': 1, 'O2': 2, 'O3': 3},
    'compressor_4_2': {'s': 0, 'c': 1, 'co': 1},
}
LEAF_OUTS = {
    'half_adder':     ['s', 'c'],
    'full_adder':     ['s', 'cout'],
    'counter_5_3':    ['o0', 'o1', 'o2'],
    'compressor_6_3': ['S', 'C1', 'C2'],
    'compressor_7_3': ['S', 'C1', 'C2'],
    'counter_15_4':   ['O0', 'O1', 'O2', 'O3'],
}
FAIL = []


def sweep_masks(nbits, N):
    out = []
    for i in range(nbits):
        blk = 1 << i
        unit = ((1 << blk) - 1) << blk
        val = 0
        for r in range(N // (2 * blk)):
            val |= unit << (r * 2 * blk)
        out.append(val)
    return out


def leaves_of(e):
    e = e.strip()
    return ([x.strip() for x in split_top_level(e[1:-1], ',')]
            if e.startswith('{') else [e])


# ---------------------------------------------------------------- 1. leaves
def check_leaves(mods):
    print("\n[1] EXHAUSTIVE LEAF VERIFICATION  (output == popcount of inputs)")
    for name, outs in LEAF_OUTS.items():
        el = Elaborator(mods)
        m = mods[name]
        pmap, in_nets = {}, []
        for pn, p in m.ports.items():
            nets = [el.nl.new() for _ in range(p.width)]
            pmap[pn] = nets
            if p.dir == 'input':
                in_nets += nets
        el.elaborate(name, name, pmap)
        order = topo_order(el.nl.gates, el.nl.n)
        n = len(in_nets)
        N = 1 << n
        drive = dict(zip(in_nets, sweep_masks(n, N)))
        v = simulate(el.nl.gates, order, el.nl.n, el.nl.const0, el.nl.const1,
                     drive, (1 << N) - 1)
        ok = True
        for j, o in enumerate(outs):
            exp = 0
            for k in range(N):
                if (bin(k).count('1') >> j) & 1:
                    exp |= 1 << k
            if v[pmap[o][0]] != exp:
                ok = False
        print("    %-16s %6d patterns   %s"
              % (name, N, "OK" if ok else "*** NOT AN EXACT COUNTER ***"))
        if not ok:
            FAIL.append("leaf %s" % name)


# ---------------------------------------------------------- 2. static audit
def audit(mods):
    print("\n[2] TOP-LEVEL STRUCTURAL AUDIT")
    top = mods['wallace_16x16']
    pp, other = {}, []
    for l, r in top.assigns:
        (pp.__setitem__(l, r) if re.fullmatch(r'pp_\d+_\d+', l) else other.append((l, r)))
    weight, seen = {}, Counter()
    for n, rhs in pp.items():
        mm = re.fullmatch(r'a\[(\d+)\]\s*&\s*b\[(\d+)\]', rhs.strip())
        if not mm:
            FAIL.append("pp rhs %s" % n); continue
        ai, bi = int(mm.group(1)), int(mm.group(2))
        r_, c_ = map(int, n.split('_')[1:])
        weight[n] = c_
        seen[(ai, bi)] += 1
        if ai + bi != c_ or bi != r_ or not (0 <= ai < 16 and 0 <= bi < 16):
            FAIL.append("pp %s mis-indexed" % n)
    print("    partial products : %d assignments, %d distinct a[i]&b[j], "
          "duplicates=%d" % (len(pp), len(seen), sum(v - 1 for v in seen.values())))
    if len(seen) != 256 or any(v > 1 for v in seen.values()):
        FAIL.append("pp multiset")

    drivers, loads = defaultdict(list), defaultdict(list)
    for n in pp:
        drivers[n].append('pp')
    for mt, inm, conns in top.insts:
        sub = mods[mt]
        if set(p for p, _ in conns) != set(sub.ports):
            FAIL.append("ports of %s" % inm)
        for p, e in conns:
            if p not in sub.ports:
                continue
            items = leaves_of(e)
            if len(items) != sub.ports[p].width:
                FAIL.append("width %s.%s" % (inm, p))
            for it in items:
                if re.fullmatch(r"\d+'\w+", it):
                    continue
                (drivers if sub.ports[p].dir == 'output' else loads)[it].append(inm)

    def vec(nm):
        for l, r in other:
            if l.strip() == nm:
                return list(reversed([x.strip() for x in
                                      split_top_level(r.strip()[1:-1], ',')]))
    A, B = vec('A'), vec('B')
    for V, nm in ((A, 'A'), (B, 'B')):
        if len(V) != 32:
            FAIL.append("%s width" % nm)
        for i, it in enumerate(V):
            if not re.fullmatch(r"\d+'\w+", it):
                loads[it].append(nm)

    md = [n for n, d in drivers.items() if len(d) > 1]
    ud = [n for n in loads if n not in drivers]
    dc = [n for n, l in loads.items() if len(l) > 1]
    dr = [n for n in drivers if n not in loads]
    print("    instances        : %d  %s"
          % (len(top.insts), dict(Counter(t for t, _, _ in top.insts))))
    print("    multiply driven  : %s" % (md or "none"))
    print("    read but undriven: %s" % (ud or "none"))
    print("    consumed twice   : %s" % (dc or "none  (no bit is double counted)"))
    print("    produced, unused : %s" % (dr or "none"))
    FAIL.extend(["multi-driven"] * bool(md) + ["undriven"] * bool(ud)
                + ["double-consumed"] * bool(dc))

    pend = list(top.insts)
    while pend:
        still, prog = [], False
        for mt, inm, conns in pend:
            sub = mods[mt]
            ins = [i for p, e in conns if sub.ports[p].dir == 'input'
                   for i in leaves_of(e) if not re.fullmatch(r"\d+'\w+", i)]
            if all(i in weight for i in ins):
                ws = set(weight[i] for i in ins)
                if len(ws) != 1:
                    FAIL.append("column mix at %s" % inm)
                    print("    [ERROR] %s mixes columns %s" % (inm, sorted(ws)))
                w0 = min(ws)
                for p, e in conns:
                    if sub.ports[p].dir == 'output':
                        weight[leaves_of(e)[0]] = w0 + OUTOFF[mt][p]
                prog = True
            else:
                still.append((mt, inm, conns))
        if not prog:
            FAIL.append("cycle"); break
        pend = still
    badAB = [(nm, i, it, weight.get(it)) for V, nm in ((A, 'A'), (B, 'B'))
             for i, it in enumerate(V)
             if not re.fullmatch(r"\d+'\w+", it) and weight.get(it) != i]
    print("    column purity    : %s"
          % ("every counter sees one column" if not any('column' in f for f in FAIL)
             else "VIOLATED"))
    print("    A/B placement    : %s" % (badAB or "every bit carries its own weight"))
    if badAB:
        FAIL.append("A/B placement")
    s = sum(2 ** weight[n] for n in pp)
    print("    conservation     : sum(2^w) over pps = %d ; (2^16-1)^2 = %d  -> %s"
          % (s, 0xFFFF ** 2, "OK" if s == 0xFFFF ** 2 else "MISMATCH"))
    if s != 0xFFFF ** 2:
        FAIL.append("conservation")
    print("    discarded bits   : %s"
          % [(n, weight.get(n)) for n in dr])
    print("      -> a discarded bit of weight 32 is provably 0 because "
          "A+B >= 0 and a*b < 2^32")


# ------------------------------------------------------------ 3. simulation
def build_sim(mods):
    el = Elaborator(mods)
    top = mods['wallace_16x16']
    pmap = {pn: [el.nl.new() for _ in range(p.width)] for pn, p in top.ports.items()}
    env = el.elaborate('wallace_16x16', 'top', pmap)
    assert not el.issues, el.issues
    order = topo_order(el.nl.gates, el.nl.n)
    OPS = {'and': '&', 'or': '|', 'xor': '^'}
    lines = []
    for gi in order:
        g = el.nl.gates[gi]
        if g[0] == 'buf':
            lines.append("n%d=n%d" % (g[1], g[2]))
        elif g[0] == 'not':
            lines.append("n%d=(~n%d)&M" % (g[1], g[2]))
        else:
            lines.append("n%d=n%d%sn%d" % (g[1], g[2], OPS[g[0]], g[3]))
    src = "def dut(%s,M,n%d,n%d):\n" % (
        ",".join("n%d" % x for x in pmap['a'] + pmap['b']),
        el.nl.const0, el.nl.const1)
    src += "".join(" %s\n" % l for l in lines)
    src += " return [%s]\n" % ",".join("n%d" % x for x in pmap['product'])
    ns = {}
    exec(compile(src, "<dut>", "exec"), ns)
    return ns['dut'], el, order


def run_sim(mods, lo, hi):
    dut, el, order = build_sim(mods)
    N = 1 << 16
    M = (1 << N) - 1
    SW = sweep_masks(16, N)
    ROWS = [[0] * 32 for _ in range(16)]
    for i in range(16):
        for j in range(16):
            ROWS[i][i + j] = SW[j]

    def golden(bv):
        acc = [0] * 32
        for i in range(16):
            if not (bv >> i) & 1:
                continue
            row, carry = ROWS[i], 0
            for k in range(i, 32):
                x, y = acc[k], row[k]
                s1 = x ^ y
                acc[k] = s1 ^ carry
                carry = (x & y) | (s1 & carry)
        return acc

    t0, bad = time.time(), 0
    for bv in range(lo, hi):
        got = dut(*SW, *[M if (bv >> i) & 1 else 0 for i in range(16)], M, 0, M)
        if got != golden(bv):
            bad += 1
            print("    MISMATCH at b=%d" % bv)
        if bv and bv % 8192 == 0:
            print("      b=%d  %.0fs" % (bv, time.time() - t0), flush=True)
    print("    %d operand pairs simulated, %d mismatching b-values, %.1fs"
          % ((hi - lo) * 65536, bad, time.time() - t0))
    if bad:
        FAIL.append("simulation")


def main():
    import sys
    d = sys.argv[1] if len(sys.argv) > 1 else '.'
    src = (open(os.path.join(d, 'wallace_blocks.v')).read() + "\n"
           + open(os.path.join(d, 'wallace_16x16.v')).read())
    mods = parse_modules(src)
    print("=" * 70)
    print("WALLACE 16x16 -- INDEPENDENT VERIFICATION")
    print("=" * 70)
    check_leaves(mods)
    audit(mods)
    print("\n[3] GATE-LEVEL SIMULATION vs INDEPENDENT SHIFT-AND-ADD REFERENCE")
    if '--exhaustive' in sys.argv:
        i = sys.argv.index('--exhaustive')
        lo = int(sys.argv[i + 1]) if len(sys.argv) > i + 1 else 0
        hi = int(sys.argv[i + 2]) if len(sys.argv) > i + 2 else 65536
        run_sim(mods, lo, hi)
    else:
        run_sim(mods, 0, 11)
        print("    (pass --exhaustive to cover all 4,294,967,296 operand pairs)")
    print("\n" + "=" * 70)
    print("RESULT: " + ("ALL CHECKS PASSED" if not FAIL
                        else "FAILURES: %s" % sorted(set(FAIL))))
    print("=" * 70)


if __name__ == '__main__':
    main()
