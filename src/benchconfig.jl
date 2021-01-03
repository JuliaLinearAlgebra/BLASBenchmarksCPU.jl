

function tmul_threads!(C, A, B)
    @tullio C[m,n] = A[m,k] * B[k,n]
end

function tmul_no_threads!(C, A, B)
    @tullio C[m,n] = A[m,k] * B[k,n] threads=false
end

function getfuncs(libs::Vector{Symbol}, threaded::Bool)::Vector{Function}
    map(libs) do i
        if i === :MKL
            gemmmkl!
        elseif i === :OpenBLAS
            gemmopenblas!
        elseif i === :PaddedMatrices
            threaded ? jmul! : jmul_single_threaded!
        elseif i === :Tullio
            threaded ? tmul_threads! : tmul_no_threads!
        elseif i === :Octavian
            matmul!
        elseif i === :Gaius
            blocked_mul!
        else
            throw("Library $i not reognized.")
        end
    end
end



