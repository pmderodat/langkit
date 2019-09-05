from __future__ import absolute_import, division, print_function

import libfoolang


print('main.py: Running...')
print('')

max_depth = 1000
ctx = libfoolang.AnalysisContext()


def parse(source):
    u = ctx.get_from_buffer('main.txt', source)
    if u.diagnostics:
        print('Diagnostics:')
        for d in u.diagnostics:
            print('  ', d)
    return u.root


def test(label, test_func):
    print('== {} =='.format(label))
    try:
        result = test_func()
    except libfoolang.PropertyError as exc:
        print('PropertyError raised: {}'.format(str(exc).strip()))
    else:
        print('Returned: {}'.format(result))
    print('')


n = parse('(1)')
test('No overflow: property calls', lambda: n.p_recurse(max_depth))
test('Overflow: property calls', lambda: n.p_recurse(max_depth + 1))

test('Overflow: lexical env lookups', lambda: n.p_recurse_lookup)

print('== Overflow parsers ==')
n = parse('{}1{}'.format('(' * max_depth, ')' * max_depth))
print('Parsinig returned: {}'.format(n))
print('')

print('main.py: Done.')
