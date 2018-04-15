module Ideals

if VERSION < v"v0.7-"
    Nothing = Void
end
using PolynomialRings.Polynomials: Polynomial
using PolynomialRings.Gröbner: gröbner_transformation

# -----------------------------------------------------------------------------
#
# Imports for overloading
#
# -----------------------------------------------------------------------------
import Base: promote_rule, convert
import Base: zero, one, in, rem, issubset, inv
import Base: +,-,*,/,//,==,!=, hash
import Base: show
import PolynomialRings: generators, expansion
import PolynomialRings: allvariablesymbols, fraction_field
import PolynomialRings.Expansions: _expansion

# -----------------------------------------------------------------------------
#
# Constructors
#
# -----------------------------------------------------------------------------

mutable struct Ideal{P<:Polynomial}
    generators::AbstractVector{P}
    _grb::Union{Nothing, AbstractVector}
    _trns::Union{Nothing, AbstractMatrix}
end
Ideal(generators::AbstractVector{<:Polynomial}) = Ideal(generators, nothing, nothing)
Ideal(generators::Polynomial...) = Ideal(collect(generators), nothing, nothing)

ring(I::Ideal{P}) where P<:Polynomial = P

# -----------------------------------------------------------------------------
#
# On-demand computed helper data
#
# -----------------------------------------------------------------------------

generators(I::Ideal) = I.generators
function _grb(I::Ideal)
    if I._grb === nothing
        I._grb, I._trns = gröbner_transformation(I.generators)
    end
    I._grb
end
function _trns(I::Ideal)
    if I._grb === nothing
        I._grb, I._trns = gröbner_transformation(I.generators)
    end
    I._trns
end

# -----------------------------------------------------------------------------
#
# Operations
#
# -----------------------------------------------------------------------------
rem(f, I::Ideal) = rem(ring(I)(f), _grb(I))
in(f, I::Ideal) = iszero(rem(f, I))

issubset(I::Ideal{P}, J::Ideal{P}) where P<:Polynomial = all(g in J for g in generators(I))
==(I::Ideal{P}, J::Ideal{P}) where P<:Polynomial = I⊆J && J⊆I

hash(I::Ideal, h::UInt) = hash(I.generators, h)

# -----------------------------------------------------------------------------
#
# Conversions
#
# -----------------------------------------------------------------------------
function convert(::Type{Ideal{P1}}, I::Ideal{P2}) where {P1<:Polynomial, P2<:Polynomial}
    return Ideal(map(P1, generators(I)))
end

# -----------------------------------------------------------------------------
#
# Display
#
# -----------------------------------------------------------------------------
show(io::IO, I::Ideal) = show(io, tuple(I.generators...))


end