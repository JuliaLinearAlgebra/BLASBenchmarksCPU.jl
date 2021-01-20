

function tmul_threads!(C, A, B)
    @tullio C[m,n] = A[m,k] * B[k,n]
end

function tmul_no_threads!(C, A, B)
    @tullio C[m,n] = A[m,k] * B[k,n] threads=false
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
        elseif i === :OpenBLAS
            gemmopenblas!
        elseif i === :BLIS || i === :blis
            gemmblis!
        elseif i === :Octavian
            matmul!
        elseif i === :Tullio
            threaded ? tmul_threads! : tmul_no_threads!
        elseif i === :Gaius
            Gaius.mul!
        elseif i === :generic || i === :Generic || i === :GENERIC
            generic_matmul!
        else
            throw("Library $i not reognized.")
        end
    end
end



