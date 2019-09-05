"""
Test that stack overflow migitations work as expected.
"""

from __future__ import absolute_import, division, print_function

from langkit.dsl import ASTNode, Field, Int, abstract
from langkit.envs import EnvSpec, reference
from langkit.expressions import If, Self, langkit_property
from langkit.parsers import Grammar, Or

from lexer_example import Token
from utils import build_and_run


class FooNode(ASTNode):
    @langkit_property(public=True, return_type=Int)
    def recurse(n=Int):
        return If(n <= 1,
                  n,
                  Self.recurse(n - 1))

    @langkit_property()
    def identity():
        return Self.node_env


@abstract
class Expression(FooNode):
    pass


class ParenExpr(FooNode):
    expr = Field()

    env_spec = EnvSpec(reference([Self.cast(FooNode)], FooNode.identity))

    @langkit_property(public=True)
    def recurse_lookup():
        return Self.node_env.get('a')


class Literal(Expression):
    token_node = True


g = Grammar('expr')
g.add_rules(
    expr=Or(g.literal, g.paren_expr),
    paren_expr=ParenExpr('(', g.expr, ')'),
    literal=Literal(Token.Number),
)
build_and_run(g, 'main.py')
print('Done')
