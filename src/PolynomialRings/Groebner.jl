module Groebner

import PolynomialRings: leading_term, lcm_multipliers
import PolynomialRings.Polynomials: Polynomial
import PolynomialRings.NamedPolynomials: NamedPolynomial
import PolynomialRings.Modules: AbstractModuleElement, AbstractNamedModuleElement, modulebasering
import PolynomialRings.Operators: leaddivrem

"""
    f_red, factors = red(f, G)

Return the multivariate reduction of a polynomial `f` by a vector of
polynomials `G`, together with  row vector of factors. By definition, this
means that no leading term of a polynomial in `G` divides any monomial in
`f`, and `f_red + factors * G == f`.

# Examples
In one variable, this is just the normal Euclidean algorithm:
```jldoctest
julia> R,(x,y) = polynomial_ring(Complex{Int}, :x, :y);
julia> red(x^1 + 1, [x-im])
(0, [x+im]')
julia> red(x^2 + y^2 + 1, [x, y])
(1, [x,y]')
```
"""
function red(f::M, G::AbstractVector{M}) where M <: AbstractModuleElement
    factors = transpose(spzeros(modulebasering(M), length(G)))
    frst = true
    more_loops = false
    f_red = f
    i = 1
    while i<=length(G)
        frst = false
        more_loops = false
        g = G[i]
        q, f_red = leaddivrem(f_red, g)
        if !iszero(q)
            factors[1, i] += q
            i = 1
        else
            i += 1
        end
        if iszero(f_red)
            return f_red, factors
        end
    end
    while i<=length(G)
        frst = false
        more_loops = false
        g = G[i]
        q, f_red = divrem(f_red, g)
        if !iszero(q)
            factors[1, i] += q
            i = 1
        else
            i += 1
        end
        if iszero(f_red)
            return f_red, factors
        end
    end

    return f_red, factors
end

_leading_row(p::Polynomial) = 1
_leading_row(a::AbstractArray) = findfirst(a)
_leading_term(p::Polynomial) = leading_term(p)
_leading_term(a::AbstractArray) = leading_term(a[_leading_row(a)])

"""
    basis, transformation = groebner_basis(polynomials)

Return a groebner basis for the ideal generated by `polynomials`, together with a
`transformation` that proves that each element in `basis` is in that ideal (i.e.
`basis == transformation * polynomials`).
"""
function groebner_basis(polynomials::AbstractVector{M}) where M <: AbstractModuleElement

    P = modulebasering(M)
    nonzero_indices = find(p->!iszero(p), polynomials)
    result = polynomials[nonzero_indices]
    transformation =Vector{P}[ P[ i==nonzero_indices[j] ? 1 : 0 for i in eachindex(polynomials)] for j in eachindex(result)]
    if length(result)>=1 # work around compiler bug for empty iterator
        pairs_to_consider = [
             (i,j) for i in eachindex(result) for j in eachindex(result) if i < j && _leading_row(polynomials[i]) == _leading_row(polynomials[j])
        ]
    else
        pairs_to_consider = Tuple{Int,Int}[]
    end

    while length(pairs_to_consider) > 0
        (i,j) = pop!(pairs_to_consider)
        a = result[i]
        b = result[j]

        lt_a = _leading_term(a)
        lt_b = _leading_term(b)

        m_a, m_b = lcm_multipliers(lt_a, lt_b)

        S = m_a * a - m_b * b

        # potential speedup: wikipedia says that in all but the 'last steps'
        # (whichever those may be), we can get away with a version of red
        # that only does lead division
        (S_red, factors) = red(S, result)

        factors[1, i] -= m_a
        factors[1, j] += m_b

        if !iszero(S_red)
            new_j = length(result)+1
            new_lr = _leading_row(S_red)
            append!(pairs_to_consider, [(new_i, new_j) for new_i in eachindex(result) if _leading_row(result[new_i]) == new_lr])
            push!(result, S_red)

            nonzero_factors = find(factors)
            tr = [ -sum(factors[x] * transformation[x][y] for x in nonzero_factors) for y in eachindex(polynomials) ]
            push!(transformation, tr)
        end
    end

    #sorted = sortperm(result, by=p->leading_term(p), rev=true)
    #result = result[sorted]
    #transformation = transformation[sorted]

    flat_tr = sparse([ transformation[x][y] for x=eachindex(result), y=eachindex(polynomials) ])

    return result, flat_tr

end

function syzygies(polynomials::AbstractVector{M}) where M <: AbstractModuleElement
    pairs_to_consider = [
        (i,j) for i in eachindex(polynomials) for j in eachindex(polynomials) if i < j
    ]

    result = Vector{RowVector{modulebasering(M),SparseVector{modulebasering(M),Int}}}()

    for (i,j) in pairs_to_consider
        a = polynomials[i]
        b = polynomials[j]
        lt_a = leading_term(a)
        lt_b = leading_term(b)

        m_a, m_b = lcm_multipliers(lt_a, lt_b)
        S = m_a * a - m_b * b

        (S_red, syzygy) = red(S, polynomials)
        if !iszero(S_red)
            throw(ArgumentError("syzygies(...) expects a Groebner basis, so S_red = $( S_red ) should be zero"))
        end
        syzygy[1,i] -= m_a
        syzygy[1,j] += m_b

        (syz_red, _) = red(syzygy, result)
        if !iszero(syz_red)
            push!(result, syz_red)
        end
        push!(result, syzygy)
    end

    flat_result = [ result[x][1,y] for x=eachindex(result), y=eachindex(polynomials) ]

    return flat_result
end

# note the double use of transpose; that's a workaround for some type-inference bug that I don't
# quite understand. Without the workaround, map(NP, factors) results in a SparseVector{Any} which
# is a recipe for disaster because there is no zero(Any).
red(f::NP, G::AbstractVector{NP}) where NP<:NamedPolynomial = ((f_red,factors) = red(f.p, map(g->g.p,G)); (NP(f_red), map(NP,factors')'))

_unpack(p) = broadcast(g->g.p, p)
_pack(::Type{NP}, a) where NP <: NamedPolynomial = broadcast(NP, a)

function groebner_basis(G::AbstractVector{M}) where M<:AbstractNamedModuleElement{NP} where NP<:NamedPolynomial
    res, tr = groebner_basis(map(_unpack,G))
    map(g->_pack(NP,g), res), map(g->_pack(NP,g), tr)
end

function syzygies(G::AbstractVector{M}) where M<:AbstractNamedModuleElement{NP} where NP<:NamedPolynomial
    res = syzygies(map(_unpack,G))
    map(g->_pack(NP,g), res)
end

end
