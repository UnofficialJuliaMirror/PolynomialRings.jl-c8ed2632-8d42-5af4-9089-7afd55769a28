module Groebner

import PolynomialRings: leading_term, lcm_multipliers, lcm_degree, fraction_field, basering, base_extend
import PolynomialRings.Polynomials: Polynomial, monomialorder, terms
import PolynomialRings.Terms: monomial
import PolynomialRings.Modules: AbstractModuleElement, modulebasering

import PolynomialRings.Util: ReadWriteLock, read_lock!, write_lock!, read_unlock!, write_unlock!


# impors for overloading
import Base: div, rem, divrem
import PolynomialRings.Operators: leaddiv, leadrem, leaddivrem

function leadrem(f::M, G::AbstractVector{M}) where M <: AbstractModuleElement
    f_red = f
    i = 1
    while i<=length(G)
        g = G[i]
        q, f_red = leaddivrem(f_red, g)
        if !iszero(q)
            i = 1
        else
            i += 1
        end
        if iszero(f_red)
            return f_red
        end
    end
    return f_red
end

function leaddivrem(f::M, G::AbstractVector{M}) where M <: AbstractModuleElement
    factors = transpose(spzeros(modulebasering(M), length(G)))
    f_red = f
    i = 1
    while i<=length(G)
        g = G[i]
        q, f_red = leaddivrem(f_red, g)
        if !iszero(q)
            factors[1, i] += q
            i = 1
        else
            i += 1
        end
        if iszero(f_red)
            return factors, f_red
        end
    end
    return factors, f_red
end

leaddiv(f::M, G::AbstractVector{M}) where M <: AbstractModuleElement = leaddivrem(f, G)[1]

"""
    f_red = rem(f, G)

Return the multivariate reduction of a polynomial `f` by a vector of
polynomials `G`. By definition, this means that no leading term of a polynomial
in `G` divides any monomial in `f`, and `f_red + factors * G == f` for some
factors.

If you need to obtain the vector of factors, use `divrem` instead.

# Examples
In one variable, this is just the normal Euclidean algorithm:
```jldoctest
julia> R,(x,y) = polynomial_ring(:x, :y, basering=Complex{Int});
julia> rem(x^1 + 1, [x-im])
0
julia> rem(x^2 + y^2 + 1, [x, y])
1
```
"""
rem(f::P, G::AbstractVector{P}) where P <: Polynomial = _rem(f,G)
rem(f::M, G::AbstractVector{M}) where M <: AbstractArray{<:Polynomial} = _rem(f,G)
function _rem(f, G)
    f_red = leadrem(f,G)

    i=1
    while i<=length(G)
        g = G[i]
        q, f_red = divrem(f_red, g)
        if !iszero(q)
            i = 1
        else
            i += 1
        end
        if iszero(f_red)
            return f_red
        end
    end

    return f_red
end

"""
    factors, f_red = divrem(f, G)

Return the multivariate reduction of a polynomial `f` by a vector of
polynomials `G`, together with  row vector of factors. By definition, this
means that no leading term of a polynomial in `G` divides any monomial in
`f`, and `f_red + factors * G == f`.

# Examples
In one variable, this is just the normal Euclidean algorithm:
```jldoctest
julia> R,(x,y) = polynomial_ring(:x, :y, basering=Complex{Int});
julia> divrem(x^1 + 1, [x-im])
(0, [x+im]')
julia> divrem(x^2 + y^2 + 1, [x, y])
(1, [x,y]')
```
"""
divrem(f::P, G::AbstractVector{P}) where P <: Polynomial = _divrem(f,G)
divrem(f::M, G::AbstractVector{M}) where M <: AbstractArray{<:Polynomial} = _divrem(f,G)
function _divrem(f, G)
    factors, f_red = leaddivrem(f,G)

    i=1
    while i<=length(G)
        g = G[i]
        q, f_red = divrem(f_red, g)
        if !iszero(q)
            factors[1, i] += q
            i = 1
        else
            i += 1
        end
        if iszero(f_red)
            return factors, f_red
        end
    end

    return factors, f_red
end

div(f::P, G::AbstractVector{P}) where P <: Polynomial = _divrem(f,G)[1]
div(f::M, G::AbstractVector{M}) where M <: AbstractArray{<:Polynomial} = _divrem(f,G)[1]

# a few functions to be able to write the same algorithm for
# computations in a free f.g. module and in a polynomial ring.
# In this context, a 'monomial' is either a monomial (polynomial ring)
# or a tuple of (index, monomial) (free f.g. module).
_leading_row(p::Polynomial) = 1
_leading_row(a::AbstractArray) = findfirst(a)
_monomials(p::Polynomial) = (monomial(t) for t in terms(p))
_monomials(a::AbstractArray) = ((i,monomial(t)) for i in find(a) for t in terms(a[i]))
_leading_term(p::Polynomial) = leading_term(p)
_leading_term(a::AbstractArray) = leading_term(a[_leading_row(a)])
_leading_monomial(p::Polynomial) = monomial(leading_term(p))
_leading_monomial(a::AbstractArray) = (i = findfirst(a); (i, _leading_monomial(a[i])))

import PolynomialRings.Monomials: AbstractMonomial, exptype, nzindices, enumeratenz, _construct

function _divisors_foreach(f::Function, a::M) where M <: AbstractMonomial

    if length(nzindices(a)) == 0
        return
    end

    e = zeros(exptype(M), last(nzindices(a)))
    nonzeros = [j for (j,_) in enumeratenz(a)]

    while true
        carry = 1
        for j = 1:length(nonzeros)
            if (e[nonzeros[j]] += carry) > a[nonzeros[j]]
                e[nonzeros[j]] = 0
                carry = 1
            else
                carry = 0
            end
        end
        if carry == 1
            break
        end
        m = _construct(M, i->e[i], nonzeros, sum(e[nonzeros]))::M
        if !f(m)
            break
        end
    end
end

_divisors_foreach(f::Function, a::Tuple{Int,M}) where M <: AbstractMonomial = _divisors_foreach(m->f((a[1],m)), a[2])

function _grb_leadred(f::M, G::AbstractVector{M}, G_lm) where M <: AbstractModuleElement
    f_red = f
    more_loops = true
    while !iszero(f_red) && more_loops
        more_loops = false
        _divisors_foreach(_leading_monomial(f_red)) do d
            range = searchsorted(G_lm, d, order=monomialorder(modulebasering(M)))
            if length(range) > 0
                i = first(range)
                (_, f_red) = leaddivrem(f_red, G[i])
                more_loops = true
                return false # break
            end
            return true # continue
        end
    end
    return f_red
end

function _grb_red(f::M, G::AbstractVector{M}, G_lm) where M <: AbstractModuleElement
    f_red = _grb_leadred(f, G, G_lm)

    more_loops = true
    while !iszero(f_red) && more_loops
        more_loops = false
        for m in _monomials(f_red)
            _divisors_foreach(m) do d
                range = searchsorted(G_lm, d, order=monomialorder(modulebasering(M)))
                if length(range) > 0
                    i = first(range)
                    (_ignored, f_red) = divrem(f_red, G[i])
                    more_loops = true
                    return false # break
                end
                return true # continue
            end
        end
    end
    return f_red
end

using DataStructures
function buchberger(polynomials::AbstractVector{M}, ::Type{Val{with_transformation}}; max_degree=Inf) where M <: AbstractModuleElement where with_transformation

    polynomials = map(base_extend, polynomials)
    P = base_extend(modulebasering(M))

    nonzero_indices = find(!iszero, polynomials)
    result = polynomials[nonzero_indices]
    result_lm = map(_leading_monomial, result)

    if with_transformation
        transformation =Vector{P}[ P[ i==nonzero_indices[j] ? 1 : 0 for i in eachindex(polynomials)] for j in eachindex(result)]
        sort_order = 1:length(result)
    else
        sort_order = sortperm(result_lm, order=monomialorder(P))
    end


    pairs_to_consider = PriorityQueue{Tuple{Int,Int}, Int}()
    for j in eachindex(result)
        for i in 1:(j-1)
            a = result[i]
            b = result[j]
            if _leading_row(a) == _leading_row(b)
                lt_a = _leading_term(a)
                lt_b = _leading_term(b)
                degree = lcm_degree(lt_a, lt_b)
                if degree <= max_degree
                    enqueue!(pairs_to_consider, (i,j), degree)
                end
            end
        end
    end


    result_lock = ReadWriteLock{Threads.Mutex}()
    log_lock = Threads.Mutex()

    loops = Threads.Atomic{Int}(0)
    Threads.@threads for thread=1:Threads.nthreads() # run code on all threads
        while true
            write_lock!(result_lock)
            if length(pairs_to_consider) == 0
                write_unlock!(result_lock)
                break
            end
            (i,j) = dequeue!(pairs_to_consider)
            write_unlock!(result_lock)

            read_lock!(result_lock)
            a = result[i]
            b = result[j]
            read_unlock!(result_lock)

            lt_a = _leading_term(a)
            lt_b = _leading_term(b)

            m_a, m_b = lcm_multipliers(lt_a, lt_b)

            S = m_a * a - m_b * b

            # potential speedup: wikipedia says that in all but the 'last steps'
            # (whichever those may be), we can get away with a version of red
            # that only does lead division
            read_lock!(result_lock)
            snapshot = result[sort_order]
            snapshot_lm = result_lm[sort_order]
            read_unlock!(result_lock)
            if with_transformation
                (factors, S_red) = divrem(S, snapshot)
            else
                S_red = _grb_red(S, snapshot, snapshot_lm)
            end

            if !iszero(S_red)
                write_lock!(result_lock)

                # we'd now like to add our new-found basis element to result, but
                # another thread may have added new elements since we created our
                # snapshot. So we do the following:
                # 1.  check whether f_red can be reduced further with the newly
                #     added elements
                # 2a. if not, add it.
                # 2b. if so, we'll have to also see whether the further reduced
                #     f_red can be further reduced.
                # In the 2b. case, we release the lock, take a new snapshot and
                # basically restart the computation. It is hoped that this is
                # either relatively rare, or is a brief computation.

                new_elements_since_snapshot = result[length(snapshot)+1:end]
                remaining_factors = div(S_red, new_elements_since_snapshot)
                while !iszero(remaining_factors)
                    # case 2b: new snapshot and new computation
                    snapshot = result[sort_order]
                    snapshot_lm = result_lm[sort_order]

                    write_unlock!(result_lock)
                    if with_transformation
                        (new_factors, S_red) = divrem(S_red, snapshot)
                        factors = new_factors + [factors zeros(remaining_factors)]
                    else
                        S_red = _grb_red(S_red, snapshot, snapshot_lm)
                    end
                    write_lock!(result_lock)

                    new_elements_since_snapshot = result[length(snapshot)+1:end]
                    remaining_factors = div(S_red, new_elements_since_snapshot)
                end
                # case 2a
                if with_transformation
                    factors = [factors remaining_factors]
                end

                if !iszero(S_red)
                    new_j = length(result)+1
                    new_lr = _leading_row(S_red)
                    new_lt = _leading_term(S_red)
                    for new_i in eachindex(result)
                        new_a = result[new_i]
                        if _leading_row(new_a) == new_lr
                            new_lt_a = _leading_term(new_a)
                            degree = lcm_degree(new_lt_a, new_lt)
                            if degree <= max_degree
                                enqueue!(pairs_to_consider, (new_i,new_j), degree)
                            end
                        end
                    end

                    S_red_lm = _leading_monomial(S_red)
                    push!(result, S_red)
                    push!(result_lm, S_red_lm)

                    if with_transformation
                        factors[1, i] -= m_a
                        factors[1, j] += m_b
                        nonzero_factors = find(factors)
                        tr = [ -sum(factors[x] * transformation[x][y] for x in nonzero_factors) for y in eachindex(polynomials) ]
                        push!(transformation, tr)

                        sort_order = 1:new_j
                    else
                        sorted_ix = searchsortedfirst(@view(result_lm[sort_order]), S_red_lm, order=monomialorder(P))
                        insert!(sort_order, sorted_ix, new_j)
                    end
                end
                write_unlock!(result_lock)
            end
            old_value = Threads.atomic_add!(loops, 1)
            if old_value % 1000 == 999
                read_lock!(result_lock)
                l = length(result)
                k = length(pairs_to_consider)
                read_unlock!(result_lock)
                lock(log_lock)
                info("Groebner: After about $(old_value+1) loops: $l elements in basis; $k pairs left to consider.")
                unlock(log_lock)
            end
        end
    end

    #sorted = sortperm(result, by=p->leading_term(p), rev=true)
    #result = result[sorted]
    #transformation = transformation[sorted]

    if with_transformation
        flat_tr = spzeros(P, length(result), length(polynomials))
        for (i,x) in enumerate(transformation)
            flat_tr[i,:] = x
        end
        return result, flat_tr
    else
        return result
    end
end

function syzygies(polynomials::AbstractVector{M}) where M <: AbstractModuleElement
    pairs_to_consider = [
        (i,j) for i in eachindex(polynomials) for j in eachindex(polynomials)
        if i < j && _leading_row(polynomials[i]) == _leading_row(polynomials[j])
    ]

    result = Vector{RowVector{modulebasering(M),SparseVector{modulebasering(M),Int}}}()

    for (i,j) in pairs_to_consider
        a = polynomials[i]
        b = polynomials[j]
        lt_a = _leading_term(a)
        lt_b = _leading_term(b)

        m_a, m_b = lcm_multipliers(lt_a, lt_b)
        S = m_a * a - m_b * b

        (syzygy, S_red) = divrem(S, polynomials)
        if !iszero(S_red)
            throw(ArgumentError("syzygies(...) expects a Groebner basis, so S_red = $( S_red ) should be zero"))
        end
        syzygy[1,i] -= m_a
        syzygy[1,j] += m_b

        syz_red = rem(syzygy, result)
        if !iszero(syz_red)
            push!(result, syz_red)
        end
    end

    flat_result = [ result[x][1,y] for x=eachindex(result), y=eachindex(polynomials) ]

    return flat_result
end

import PolynomialRings.Backends
import PolynomialRings.Backends.Groebner: Buchberger
"""
    basis, transformation = groebner_transformation(polynomials)

Return a groebner basis for the ideal generated by `polynomials`, together with a
`transformation` that proves that each element in `basis` is in that ideal (i.e.
`basis == transformation * polynomials`).
"""
groebner_transformation(G; kwds...) = groebner_transformation(Backends.Groebner.default, G, kwds...)
"""
    basis = groebner_basis(polynomials)

Return a groebner basis for the ideal generated by `polynomials`.
"""
groebner_basis(G; kwds...) = groebner_basis(Backends.Groebner.default, G, kwds...)

groebner_transformation(::Buchberger, G; kwds...) = buchberger(G, Val{true}, kwds...)
groebner_basis(::Buchberger, G; kwds...) = buchberger(G, Val{false}, kwds...)

# FIXME: why doesn't this suppress info(...) output?
logging(DevNull, current_module(), kind=:info)

end
