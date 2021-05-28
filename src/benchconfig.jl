

function tmul_threads!(C, A, B)
    @tullio C[m,n] = A[m,k] * B[k,n]
end
function tmul_no_threads!(C, A, B)
    @tullio C[m,n] = A[m,k] * B[k,n] threads=false
end
function lvmul_threads!(C, A, B)
    @avxt for n ∈ indices((C,B), 2), m ∈ indices((C,A), 1)
        Cmn = zero(eltype(C))
        for k ∈ indices((A,B), (2,1))
            Cmn += A[m,k] * B[k,n]
        end
        C[m,n] = Cmn
    end
end
function lvmul_no_threads!(C, A, B)
    @avx for n ∈ indices((C,B), 2), m ∈ indices((C,A), 1)
        Cmn = zero(eltype(C))
        for k ∈ indices((A,B), (2,1))
            Cmn += A[m,k] * B[k,n]
        end
        C[m,n] = Cmn
    end
end

function generic_matmul!(C, A, B)
    istransposed(C) === 'N' || (generic_matmul!(untransposed(C), _transpose(B), _transpose(A)); return C)
    transA = istransposed(A)
    transB = istransposed(B)
    pA     = untransposed(A);
    pB     = untransposed(B)
    LinearAlgebra.generic_matmatmul!(C, transA, transB, pA, pB)
end



function getfuncs(libs::Vector{Symbol}, threaded::Bool)::Vector{Function}
    map(libs) do i
        if i === :MKL
            gemmmkl!
        elseif i === :MKL_DIRECT || i === :MKL_direct
            gemmmkl_direct!
        elseif i === :OpenBLAS
            gemmopenblas!
        elseif i === :BLIS || i === :blis
            gemmblis!
        elseif i === :Octavian
            threaded ? matmul! : matmul_serial!
        elseif i === :Tullio
            threaded ? tmul_threads! : tmul_no_threads!
        elseif i === :Gaius
            threaded ? Gaius.mul! : Gaius.mul_serial!
        elseif i === :LoopVectorization
            threaded ? lvmul_threads! : lvmul_no_threads!
        elseif i === :generic || i === :Generic || i === :GENERIC
            generic_matmul!
        else
            throw("Library $i not reognized.")
        end
    end
end



