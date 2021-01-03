
istransposed(x) = 'N'
istransposed(x::Adjoint) = 'C'
istransposed(x::Adjoint{<:Real}) = 'T'
istransposed(x::Transpose) = 'T'

untransposed(A) = A
untransposed(A::Adjoint) = adjoint(A)
untransposed(A::Transpose) = transpose(A)

_transpose(A) = A'
_transpose(A::Adjoint) = adjoint(A)
_transpose(A::Transpose) = transpose(A)

for (name,typ,suff) ∈ [
    ("mkl", :Int32, ""),
    ("openblas", :Int64, "_64_")
]
    uname = uppercase(name)
    lib = Symbol("lib", uname)
    f = Symbol("gemm", name, '!')
    for (T,prefix) ∈ [(:Float32,'s'),(:Float64,'d')]
        fm = QuoteNode(Symbol(prefix, "gemm", suff))
        @eval begin
            function $f(
                C::AbstractMatrix{$T}, A::AbstractMatrix{$T}, B::AbstractMatrix{$T}, α = one($T), β = zero($T)
            )
                istransposed(C) === 'N' || ($f(untransposed(C), _transpose(B), _transpose(A)); return C)
                transA = istransposed(A)
                transB = istransposed(B)
                pA     = untransposed(A);
                pB     = untransposed(B)
                M, N = size(C); K = size(B, 1)
                ldA = stride(pA, 2)
                ldB = stride(pB, 2)
                ldC = stride(C, 2)
                ccall(
                    ($fm, $lib), Cvoid,
                    (Ref{UInt8}, Ref{UInt8}, Ref{Int64}, Ref{Int64}, Ref{Int64}, Ref{$T}, Ref{$T},
                     Ref{Int64}, Ref{$T}, Ref{Int64}, Ref{$T}, Ref{$T}, Ref{Int64}),
                    transA, transB, M, N, K, α, pA, ldA, pB, ldB, β, C, ldC
                )
                C
            end
            
        end
    end
end

