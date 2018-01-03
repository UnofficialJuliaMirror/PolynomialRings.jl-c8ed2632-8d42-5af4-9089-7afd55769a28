module Modules

using Nulls

import PolynomialRings.Polynomials: Polynomial, monomialorder
import PolynomialRings.MonomialOrderings: MonomialOrder
import PolynomialRings.Monomials: AbstractMonomial
import PolynomialRings.Terms: Term
import PolynomialRings.Operators: RedType

# -----------------------------------------------------------------------------
#
# Imports for overloading
#
# -----------------------------------------------------------------------------
import Base: iszero, div, rem, divrem, *, ==
import Base.Order: lt
import PolynomialRings: leading_row, leading_term, leading_monomial, base_extend
import PolynomialRings: termtype, monomialtype
import PolynomialRings: maybe_div, lcm_degree, lcm_multipliers
import PolynomialRings.Operators: leaddiv, leadrem, leaddivrem
import PolynomialRings.Terms: coefficient, monomial
import PolynomialRings.Monomials: total_degree

# -----------------------------------------------------------------------------
#
# An abstract module element is either a ring element (module over itself) or
# an array.
#
# -----------------------------------------------------------------------------
AbstractModuleElement{P<:Polynomial} = Union{P, AbstractArray{P}}
modulebasering(::Type{A}) where A <: AbstractModuleElement{P} where P<:Polynomial = P
modulebasering(::A)       where A <: AbstractModuleElement{P} where P<:Polynomial = modulebasering(A)

iszero(x::AbstractArray{P}) where P<:Polynomial = (i = findfirst(x); i>0 ? iszero(x[i]) : true)

base_extend(x::AbstractArray{P}, ::Type{C}) where P<:Polynomial where C = map(p->base_extend(p,C), x)
base_extend(x::AbstractArray{P})            where P<:Polynomial         = map(base_extend, x)

# -----------------------------------------------------------------------------
#
# The signature of a module element is just its leading monomial. We represent
# it by an index and the leading monomial at that index.
# an array.
#
# -----------------------------------------------------------------------------
struct Signature{M,I}
    i::I
    m::M
end

termtype(p::AbstractArray{<:Polynomial}) = Signature{termtype(eltype(p)), Int}
monomialtype(p::AbstractArray{<:Polynomial}) = Signature{monomialtype(eltype(p)), Int}

*(s::Signature,m::Union{AbstractMonomial,Term})  = Signature(s.i, s.m * m)
*(m::Union{AbstractMonomial,Term}, s::Signature) = Signature(s.i, s.m * m)
maybe_div(s::Signature, t::Signature)            = s.i == t.i ? maybe_div(s.m, t.m) : null
lcm_degree(s::Signature, t::Signature)           = s.i == t.i ? lcm_degree(s.m, t.m) : null
lcm_multipliers(s::Signature, t::Signature)      = s.i == t.i ? lcm_multipliers(s.m, t.m) : null
total_degree(s::Signature)                       = total_degree(s.m)
lt(o::MonomialOrder, s::Signature, t::Signature) = s.i > t.i || (s.i == t.i && lt(o, s.m, t.m))
==(s::S, t::S) where S <: Signature = s.i == t.i && s.m == t.m

coefficient(s::Signature{<:Term}) = coefficient(s.m)
monomial(s::Signature{<:Term}) = Signature(s.i, monomial(m))


leading_row(x::AbstractArray{<:Polynomial}) = findfirst(x)
leading_term(x::AbstractArray{P}) where P<:Polynomial = leading_term(monomialorder(P), x)
leading_term(o::MonomialOrder, x::AbstractArray{P}) where P<:Polynomial = Signature(leading_row(x), leading_term(o, x[leading_row(x)]))
leading_monomial(x::AbstractArray{P}) where P<:Polynomial = leading_monomial(monomialorder(P), x)
leading_monomial(o::MonomialOrder, x::AbstractArray{P}) where P<:Polynomial = Signature(leading_row(x), leading_monomial(o, x[leading_row(x)]))

function divrem(redtype::RedType, o::MonomialOrder, a::A, b::A) where A<:AbstractArray{<:Polynomial}
    i = findfirst(b)
    if i>0
        (q,r) = divrem(redtype, o, a[i], b[i])
        if iszero(q)
            # make sure to maintain object identity for a
            return q, a
        else
            return q, a - q*b
        end
    else
        return zero(P), a
    end
end

div(redtype::RedType, o::MonomialOrder, a::A, b::A) where A<:AbstractArray{<:Polynomial} = divrem(redtype, o, a, b)[1]
rem(redtype::RedType, o::MonomialOrder, a::A, b::A) where A<:AbstractArray{<:Polynomial} = divrem(redtype, o, a, b)[2]

leaddivrem(f::A,g::AbstractVector{A}) where A<:AbstractArray{P} where P<:Polynomial = divrem(Lead(), monomialorder(P), f, g)
divrem(f::A,g::AbstractVector{A})     where A<:AbstractArray{P} where P<:Polynomial = divrem(Full(), monomialorder(P), f, g)
leadrem(f::A,g::AbstractVector{A})    where A<:AbstractArray{P} where P<:Polynomial = rem(Lead(), monomialorder(P), f, g)
rem(f::A,g::AbstractVector{A})        where A<:AbstractArray{P} where P<:Polynomial = rem(Full(), monomialorder(P), f, g)
leaddiv(f::A,g::AbstractVector{A})    where A<:AbstractArray{P} where P<:Polynomial = div(Lead(), monomialorder(P), f, g)
div(f::A,g::AbstractVector{A})        where A<:AbstractArray{P} where P<:Polynomial = div(Full(), monomialorder(P), f, g)


# compatibility: a ring is just a rank-one module over itself, so the 'leading'
# row is just the first one.
leading_row(x::Polynomial) = 1

end
