
using LinearAlgebra: Adjoint, Transpose, UnitLowerTriangular, LowerTriangular, UnitUpperTriangular, UpperTriangular, AbstractTriangular

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


uplochar(::Union{LowerTriangular,UnitLowerTriangular}) = 'L'
uplochar(::Union{UpperTriangular,UnitUpperTriangular}) = 'U'
diagchar(::Union{LowerTriangular,UpperTriangular}) = 'N'
diagchar(::Union{UnitLowerTriangular,UnitUpperTriangular}) = 'U'
untranspose_flag(A::Adjoint, f::Bool = false) = untranspose_flag(parent(A), !f)
untranspose_flag(A::Transpose, f::Bool = false) = untranspose_flag(parent(A), !f)
untranspose_flag(A, f::Bool = false) = (A, f)

struct LU{T,M<:StridedMatrix{T},I}
  factors::M
  ipiv::Vector{I}
  info::I
end
function getrf_ipiv(A::StridedMatrix, ::Val{T}) where {T}
  M,N = size(A)
  Vector{T}(undef, min(M,N))
end

function _ipiv_rows!(A::LU, order::OrdinalRange, B::StridedVecOrMat)
  @inbounds for i ∈ order
    i ≠ A.ipiv[i] && LinearAlgebra._swap_rows!(B, i, A.ipiv[i])
  end
  B
end
_apply_ipiv_rows!(A::LU, B::StridedVecOrMat) = _ipiv_rows!(A, 1 : length(A.ipiv), B)
function _ipiv_cols!(A::LU, order::OrdinalRange, B::StridedVecOrMat)
  ipiv = A.ipiv
  @inbounds for i ∈ order
    i ≠ ipiv[i] && LinearAlgebra._swap_cols!(B, i, ipiv[i])
  end
  B
end
_apply_inverse_ipiv_cols!(A::LU, B::StridedVecOrMat) = _ipiv_cols!(A, length(A.ipiv) : -1 : 1, B)

for (name,BlasInt,suff) ∈ [
  ("mkl", :Int32, ""),
  ("openblas", :Int64, "_64_"),
  ("blis", :Int64, "_64_")
]
  uname = uppercase(name)
  lib = Symbol("lib", uname)
  fgemm = Symbol("gemm", name, '!')
  fgetrf = Symbol("getrf", name, '!')
  ftrsm = Symbol("trsm", name, '!')
  frdiv = Symbol("rdiv", name)
  fldiv = Symbol("ldiv", name)
  frdivbang = Symbol("rdiv", name, '!')
  fldivbang = Symbol("ldiv", name, '!')
  flu = Symbol("lu", name)
  flubang = Symbol("lu", name, '!')
  for (T,prefix) ∈ [(:Float32,'s'),(:Float64,'d')]
    fmgemm = QuoteNode(Symbol(prefix, "gemm", suff))
    fmgetrf = QuoteNode(Symbol(prefix, "getrf", suff))
    fmtrsm = QuoteNode(Symbol(prefix, "trsm", suff))
    @eval begin
      function $fgemm(
        C::AbstractMatrix{$T}, A::AbstractMatrix{$T}, B::AbstractMatrix{$T}, α = one($T), β = zero($T)
      )
        istransposed(C) === 'N' || ($fgemm(untransposed(C), _transpose(B), _transpose(A)); return C)
        transA = istransposed(A)
        transB = istransposed(B)
        pA     = untransposed(A);
        pB     = untransposed(B)
        M, N = size(C); K = size(B, 1)
        ldA = stride(pA, 2)
        ldB = stride(pB, 2)
        ldC = stride(C, 2)
        ccall(
          ($fmgemm, $lib), Cvoid,
          (Ref{UInt8}, Ref{UInt8}, Ref{$BlasInt}, Ref{$BlasInt}, Ref{$BlasInt}, Ref{$T}, Ref{$T},
           Ref{$BlasInt}, Ref{$T}, Ref{$BlasInt}, Ref{$T}, Ref{$T}, Ref{$BlasInt}),
          transA, transB, M, N, K, α, pA, ldA, pB, ldB, β, C, ldC
        )
        C
      end
    end
    name == "blis" && continue
    @eval begin
      function $fgetrf(
        A::StridedMatrix{$T}, ipiv::StridedVector{$BlasInt} = getrf_ipiv(A, Val($BlasInt))
      )
        M, N = size(A)
        info = Ref{$BlasInt}()
        ccall(
          ($fmgetrf,$lib), Cvoid, (Ref{$BlasInt},Ref{$BlasInt},Ptr{$T},Ref{$BlasInt},Ptr{$BlasInt},Ref{$BlasInt}),
          M, N, A, max(1,stride(A,2)), ipiv, info
        )
        LU(A, ipiv, info[])
      end
      function $ftrsm(
        B::StridedMatrix{$T}, α::$T, A::AbstractMatrix{$T}, side::Char
      ) 
        M, N = size(A)
        pA, transa = untranspose_flag(A)
        uplo = uplochar(pA)
        diag = diagchar(pA)
        ppA = parent(pA)
        ccall(
          ($fmtrsm, $lib), Cvoid, (Ref{UInt8}, Ref{UInt8}, Ref{UInt8}, Ref{UInt8}, Ref{$BlasInt}, Ref{$BlasInt}, Ref{$T}, Ptr{Float64}, Ref{$BlasInt}, Ptr{$T}, Ref{$BlasInt}),
          side, uplo, ifelse(transa, 'T', 'N'), diag, M % $BlasInt, N % $BlasInt, α, ppA, max(1,stride(ppA,2)), B, max(1,stride(B,2))
        )
        B
      end
    end
  end
  name == "blis" && continue
  @eval begin
    function $frdivbang(
      A::StridedMatrix{T}, B::AbstractTriangular{T}
    ) where {T <: Union{Float32,Float64}}
      $ftrsm(A, one(T), B, 'R')
    end
    function $fldivbang(
      A::StridedMatrix{T}, B::AbstractTriangular{T}
    ) where {T <: Union{Float32,Float64}}
      $ftrsm(A, one(T), B, 'L')
    end
    $flubang(A::StridedMatrix) = $fgetrf(A, getrf_ipiv(A, Val($BlasInt)))
    $flu(A::StridedMatrix) = $flubang(copy(A))
    function $frdivbang(A::AbstractMatrix, B::LU{<:Any,<:AbstractMatrix})
      $frdivbang($frdivbang(A, UpperTriangular(B.factors)), UnitLowerTriangular(B.factors))
      _apply_inverse_ipiv_cols!(B, A) # mutates `A`
    end
    function $fldivbang(A::LU{<:Any,<:AbstractMatrix}, B::AbstractMatrix)
      _apply_ipiv_rows!(A, B)
      $fldivbang($fldivbang(B, UnitLowerTriangular(A.factors)), UpperTriangular(A.factors))
    end

    $frdivbang(A::AbstractMatrix, B::AbstractMatrix) = $frdivbang(A, $flubang(B))
    $fldivbang(A::AbstractMatrix, B::AbstractMatrix) = $fldivbang($flubang(A), B)

    $frdiv(A::AbstractMatrix, B) = $frdivbang(copy(A), copy(B))
    $fldiv(A::AbstractMatrix, B) = $fldivbang(copy(A), copy(B))

  end
end
let BlasInt = :Int32
  for (T,prefix) ∈ [(:Float32,'s'),(:Float64,'d')]
    f = Symbol(prefix, "gemm_direct")
    @eval begin
      @inline function gemmmkl_direct!(C::AbstractMatrix{$T}, A::AbstractMatrix{$T}, B::AbstractMatrix{$T}, α = one($T), β = zero($T))
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
          ($(QuoteNode(f)), libMKL), Cvoid,
          (Ref{UInt8}, Ref{UInt8}, Ref{$BlasInt}, Ref{$BlasInt}, Ref{$BlasInt}, Ref{$T}, Ref{$T},
           Ref{$BlasInt}, Ref{$T}, Ref{$BlasInt}, Ref{$T}, Ref{$T}, Ref{$BlasInt}, Ref{$BlasInt}),
          transA, transB, M, N, K, α, pA, ldA, pB, ldB, β, C, ldC, 0
        )
        C
      end
    end
  end
end




