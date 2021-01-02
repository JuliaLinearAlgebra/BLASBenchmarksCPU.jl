
istransposed(x) = 'N'
istransposed(x::Adjoint{<:Real}) = 'T'
istransposed(x::Adjoint) = 'C'
istransposed(x::Transpose) = 'T'

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
                transA = istransposed(A)
                transB = istransposed(B)
                M, N = size(C); K = size(B, 1)
                pA = parent(A); pB = parent(B)
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

