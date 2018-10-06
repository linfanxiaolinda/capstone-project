#############################################################################
# Course: YSC4103 MCS Capstone
# Date created: 2018/09/21
# Name: Linfan XIAO
# Description: Algorithm to construct a valid adjoint boundary condition from a given (homogeneous) boundary condition based on Chapter 11 in Theory of Ordinary Differential Equations (Coddington & Levinson). The implementation uses Julia functions as main objects but supports symbolic expressions in the form of Julia struct attributes.
#############################################################################
# Importing packages
#############################################################################
using SymPy
using Roots
using Distributions
#############################################################################
# Helper functions
#############################################################################
# Check whether all elements in a not necessarily homogeneous array satisfy a given condition.
function check_all(array, condition)
    for x in array
        if !condition(x)
            return false
        end
    end
    return true
end

# Set an appropriate tolerance when checking whether x \approx y
function set_tol(x::Number, y::Number)
    return 1e-09 * mean([x y])
end

# Evaluate function on x where the function is Function, SymPy.Sym, or Number.
function evaluate(func::Union{Function,Number}, x::Number, t=nothing)
    if isa(func, Function)
        return func(x)
    elseif isa(func, SymPy.Sym) # SymPy.Sym must come before Number because SymPy.Sym will be recognized as Number
        return subs(func, t, x)
    else
        return func
    end
end

# Assign string as variable name
function assign(s::AbstractString, v::Any)
    s=Symbol(s)
    @eval (($s) = ($v))
end

# Generate two-integer partitions of n
function partition(n::Int)
    output = []
    for i = 0:n
        j = n - i
        push!(output, (i,j))
    end
    return output
end

# Construct the symbolic expression for the kth derivative of u with respect to t
function deriv(u::SymPy.Sym, t::SymPy.Sym, k::Int)
    if k < 0
        error("Only nonnegative degrees are allowed")
    end
    y = u
    for i = 1:k
        newY = diff(y, t)
        y = newY
    end
    return y
end

# Function addition (f + g)(x) := f(x) + g(x)
function add_func(f::Union{Number, Function}, g::Union{Number, Function})
    function h(x)
        if isa(f, Number)
            if isa(g, Number)
                return f + g
            else
                return f + g(x)
            end
        elseif isa(f, Function)
            if isa(g, Number)
                return f(x) + g
            else
                return f(x) + g(x)
            end
        end
    end
    return h
end

# Function multiplication (f * g)(x) := f(x) * g(x)
function mult_func(f::Union{Number, Function}, g::Union{Number, Function})
    function h(x)
        if isa(f, Number)
            if isa(g, Number)
                return f * g
            else
                return f * g(x)
            end
        elseif isa(f, Function)
            if isa(g, Number)
                return f(x) * g
            else
                return f(x) * g(x)
            end
        end
    end
    return h
end

# Evaluate a matrix at t=a.
# Entries of B may be Function, Number, or Sympy.Sym.
function evaluate_matrix(matrix::Array, a::Number, t=nothing)
    (m, n) = size(matrix)
    matrixA = Array{Number}(m,n)
    for i = 1:m
        for j = 1:n
            matrixA[i,j] = evaluate(matrix[i,j], a, t)
        end
    end
    return matrixA
end
#############################################################################
# Structs
#############################################################################
# A struct definition error type is the class of all errors in a struct definition
struct StructDefinitionError <: Exception
    msg::String
end

# A symbolic linear differential operator of order n is encoded by an 1 x (n+1) array of symbolic expressions and an interval [a,b].
struct SymLinearDifferentialOperator
    # Entries in the array should be SymPy.Sym or Number. SymPy.Sym seems to be a subtype of Number, i.e., Array{Union{Number,SymPy.Sym}} returns Array{Number}. But specifying symPFunctions as Array{Number,2} gives a MethodError when the entries are Sympy.Sym objects.
    symPFunctions::Array
    interval::Tuple{Number,Number}
    t::SymPy.Sym
    SymLinearDifferentialOperator(symPFunctions::Array, interval::Tuple{Number,Number}, t::SymPy.Sym) =
    try
        symL = new(symPFunctions, interval, t)
        check_symLinearDifferentialOperator_input(symL)
        return symL
    catch err
        throw(err)
    end
end

function check_symLinearDifferentialOperator_input(symL::SymLinearDifferentialOperator)
    symPFunctions, (a,b), t = symL.symPFunctions, symL.interval, symL.t
    for symPFunc in symPFunctions
        if isa(symPFunc, SymPy.Sym)
            if size(free_symbols(symPFunc)) != (1,) && size(free_symbols(symPFunc)) != (0,)
                throw(StructDefinitionError(:"Only one free symbol is allowed in symP_k"))
            end
        elseif !isa(symPFunc, Number)
            throw(StructDefinitionError(:"symP_k should be SymPy.Sym or Number"))
        end
    end
    return true
end

# A linear differential operator of order n is encoded by an 1 x (n+1) array of functions, an interval [a,b], and its symbolic expression.
struct LinearDifferentialOperator
    pFunctions::Array # Array of julia functions or numbers representing constant functions
    interval::Tuple{Number,Number}
    symL::SymLinearDifferentialOperator
    LinearDifferentialOperator(pFunctions::Array, interval::Tuple{Number,Number}, symL::SymLinearDifferentialOperator) =
    try
        L = new(pFunctions, interval, symL)
        check_linearDifferentialOperator_input(L)
        return L
    catch err
        throw(err)
    end
end

# Assume symFunc has only one free symbol, as required by the definition of SymLinearDifferentialOperator. 
# That is, assume the input symFunc comes from SymLinearDifferentialOperator.
function check_func_sym_equal(func::Union{Function,Number}, symFunc, interval::Tuple{Number,Number}, t::SymPy.Sym) # symFunc should be Union{SymPy.Sym, Number}, but somehow SymPy.Sym gets ignored
    (a,b) = interval
    # Randomly sample 100 points from (a,b) and check if func and symFunc agree on them
    for i = 1:10
        # Check endpoints
        if i == 1
            x = a
        elseif i == 2
            x = b
        else
            x = rand(Uniform(a,b), 1)[1,1]
        end
        funcEvalX = evaluate(func, x)
        if isa(symFunc, SymPy.Sym)
            symFuncEvalX = N(subs(symFunc,t,x))
            # N() converts SymPy.Sym to Number
            # https://docs.sympy.org/latest/modules/evalf.html
            # subs() works no matter symFunc is Number or SymPy.Sym
        else
            symFuncEvalX = symFunc
        end
        tol = set_tol(funcEvalX, symFuncEvalX)
        if !isapprox(funcEvalX, symFuncEvalX; atol = tol)
            return false
        end
    end
    return true
end

# Check whether the inputs of L are valid.
function check_linearDifferentialOperator_input(L::LinearDifferentialOperator)
    pFunctions, (a,b), symL = L.pFunctions, L.interval, L.symL
    symPFunctions, t = symL.symPFunctions, symL.t
    p0 = pFunctions[1]
    if !check_all(pFunctions, pFunc -> (isa(pFunc, Function) || isa(pFunc, Number)))
        throw(StructDefinitionError(:"p_k should be Function or Number"))
    elseif length(pFunctions) != length(symPFunctions)
        throw(StructDefinitionError(:"Number of p_k and symP_k do not match"))
    elseif (a,b) != symL.interval
        throw(StructDefinitionError(:"Intervals do not match"))
    # Assume p_k are in C^{n-k}. Check whether p0 vanishes on [a,b].
    elseif (isa(p0, Function) && (length(find_zeros(p0, a, b)) != 0 || p0(a) == 0 || p0(b) == 0)) || p0 == 0 
        throw(StructDefinitionError(:"p0 vanishes on [a,b]"))
    elseif !all(i -> check_func_sym_equal(pFunctions[i], symPFunctions[i], (a,b), t), 1:length(pFunctions))
        throw(StructDefinitionError(:"symP_k does not agree with p_k on [a,b]"))
    else
        return true
    end
end

# A boundary condition Ux = 0 is encoded by an ordered pair of two matrices (M, N) whose entries are Numbers.
struct VectorBoundaryForm
    M::Array # Why can't I specify Array{Number,2} without having a MethodError?
    N::Array
    VectorBoundaryForm(M::Array, N::Array) =
    try
        U = new(M, N)
        check_vectorBoundaryForm_input(U)
        return U
    catch err
        throw(err)
    end
end

# Check whether the input matrices that characterize U are valid
function check_vectorBoundaryForm_input(U::VectorBoundaryForm)
    M, N = U.M, U.N
    if !(check_all(M, x -> isa(x, Number)) && check_all(N, x -> isa(x, Number)))
        throw(StructDefinitionError(:"Entries of M, N should be Number"))
    elseif size(M) != size(N)
        throw(StructDefinitionError(:"M, N dimensions do not match"))
    elseif size(M)[1] != size(M)[2]
        throw(StructDefinitionError(:"M, N should be square matrices"))
    elseif rank(hcat(M, N)) != size(M)[1]
        throw(StructDefinitionError(:"Boundary operators not linearly independent"))
    else
        return true
    end
end

#############################################################################
# Functions
#############################################################################
# Calculate the rank of U, i.e., rank(M:N)
function rank_of_U(U::VectorBoundaryForm)
    M, N = U.M, U.N
    MHcatN = hcat(M, N)
    return rank(MHcatN)
end

# Find Uc, a complementary form of U
function get_Uc(U::VectorBoundaryForm)
    try
        check_vectorBoundaryForm_input(U)
        n = rank_of_U(U)
        I = eye(2*n)
        M, N = U.M, U.N
        MHcatN = hcat(M, N)
        mat = MHcatN
        for i = 1:(2*n)
            newMat = vcat(mat, I[i:i,:])
            if rank(newMat) == rank(mat) + 1
                mat = newMat
            end
        end
        UcHcat = mat[(n+1):(2n),:]
        Uc = VectorBoundaryForm(UcHcat[:,1:n], UcHcat[:,(n+1):(2n)])
        return Uc
    catch err
        return err
    end
end

# Construct H from M, N, Mc, Nc
function get_H(U::VectorBoundaryForm, Uc::VectorBoundaryForm)
    MHcatN = hcat(U.M, U.N)
    McHcatNc = hcat(Uc.M, Uc.N)
    H = vcat(MHcatN, McHcatNc)
    return H
end

# Construct a matrix whose ij-entry is a string "pij" which denotes the jth derivative of p_i
function get_pStringMatrix(L::Union{LinearDifferentialOperator, SymLinearDifferentialOperator})
    if isa(L, LinearDifferentialOperator)
        pFunctions = L.pFunctions
    else
        pFunctions = L.symPFunctions
    end
    n = length(pFunctions)-1
    pStringMatrix = Array{String}(n,n)
    for i in 0:(n-1)
        for j in 0:(n-1)
            pStringMatrix[i+1,j+1] = string("p", i,j)
        end
    end
    return pStringMatrix
end

# Construct a matrix whose ij-entry is the symbolic expression of the jth derivative of p_i.
function get_symPDerivMatrix(symL::SymLinearDifferentialOperator, substitute = false)
    symPFunctions, t = symL.symPFunctions, symL.t
    n = length(symPFunctions)-1
    symPDerivMatrix = Array{SymPy.Sym}(n,n)
    if substitute
        pFunctionSymbols = symPFunctions
    else
        pFunctionSymbols = [SymFunction(string("p", i))(t) for i in 0:(n-1)]
    end
    for i in 1:n
        for j in 1:n
            index, degree = i-1, j-1
            symPDeriv = pFunctionSymbols[index+1]
            symPDerivMatrix[i,j] = deriv(symPDeriv, t, degree)
        end
    end
    return symPDerivMatrix
end

# For L, the above matrix would need to be constructed by hand.
# pDerivMatrix = 

# Create the symbolic expression for [uv](t).
# If substitute is true: Substitute the p_k SymFunctions with SymPy.Sym definitions, e.g., substitute p0 by t + 1.
function get_symUvForm(symL::SymLinearDifferentialOperator, u::SymPy.Sym, v::SymPy.Sym, substitute = false)
    symPFunctions, t = symL.symPFunctions, symL.t
    n = length(symPFunctions)-1
    if substitute
        pFunctionSymbols = symPFunctions
    else
        pFunctionSymbols = [SymFunction(string("p", i))(t) for i in 0:(n-1)]
    end
    sum = 0
    for m = 1:n
        for (j,k) in partition(m-1)
            summand = (-1)^j * deriv(u, t, k) * deriv(pFunctionSymbols[n-m+1] * conj(v), t, j)
            sum += summand
        end
    end
    sum = expand(sum)
    return sum
end

# Find symbolic expression for Bjk using explicit formula.
# If substitute is true: Substitute the p_k SymFunctions with SymPy.Sym definitions, e.g., substitute p0 by t + 1.
function get_symBjk(symL::SymLinearDifferentialOperator, j::Int, k::Int, substitute = false)
    n = length(symL.symPFunctions)-1
    sum = 0
    matrix = get_symPDerivMatrix(symL, substitute)
    for l = (j-1):(n-k)
        summand = binomial(l, j-1) * matrix[n-k-l+1, l-j+1+1] * (-1)^l
        sum += summand
    end
    return sum
end

# Find symbolic B using explicit formula.
# If substitute is true: Substitute the p_k SymFunctions with SymPy.Sym definitions, e.g., substitute p0 by t + 1.
function get_symB(symL::SymLinearDifferentialOperator, substitute = false)
    n = length(symL.symPFunctions)-1
    B = Array{Any}(n,n)
    for j = 1:n
        for k = 1:n
            B[j,k] = get_symBjk(symL, j, k, substitute)
        end
    end
    return B
end

# Find Bjk using explicit formula
function get_Bjk(L::LinearDifferentialOperator, j::Int, k::Int, pDerivMatrix::Array)
    n = length(L.pFunctions)-1
    sum = 0
    for l = (j-1):(n-k)
        summand = mult_func(binomial(l, j-1) * (-1)^l, pDerivMatrix[n-k-l+1, l-j+1+1])
        sum = add_func(sum, summand)
    end
    return sum
end

# Construct the B matrix using explicit formula
function get_B(L::LinearDifferentialOperator, pDerivMatrix::Array)
    n = length(L.pFunctions)-1
    B = Array{Any}(n,n)
    for j = 1:n
        for k = 1:n
            B[j,k] = get_Bjk(L, j, k, pDerivMatrix)
        end
    end
    return B
end

# Construct B_hat
function get_BHat(L::LinearDifferentialOperator, B::Array)
    pFunctions, (a,b) = L.pFunctions, L.interval
    n = length(pFunctions)-1
    BHat = Array{Number}(2n,2n)
    BEvalA = evaluate_matrix(B, a)
    BEvalB = evaluate_matrix(B, b)
    BHat[1:n,1:n] = -BEvalA
    BHat[(n+1):(2n),(n+1):(2n)] = BEvalB
    BHat[1:n, (n+1):(2n)] = 0
    BHat[(n+1):(2n), 1:n] = 0
    return BHat
end

# Construct J = (B_hat * H^{(-1)})^*, where ^* denotes conjugate transpose
function get_J(BHat, H)
    n = size(H)[1]
    J = (BHat * inv(H))'
    return J
end

# Construct U+
function get_adjoint(J)
    n = convert(Int, size(J)[1]/2)
    Pstar = J[(n+1):2n,1:n]
    Qstar = J[(n+1):2n, (n+1):2n]
    adjoint = VectorBoundaryForm(Pstar, Qstar)
    return adjoint
end

# Construct \xi = [x; x'; x''; ...], an n x 1 vector of derivatives of x(t)
function get_symXi(L::Union{LinearDifferentialOperator, SymLinearDifferentialOperator}, substitute = false, xDef = nothing)
    if isa(L, LinearDifferentialOperator)
        pFunctions = L.pFunctions
    else
        pFunctions = L.symPFunctions
    end
    n = length(pFunctions)
    t = symbols("t")
    symXi = Array{SymPy.Sym}(n,1)
    
    if !substitute
        xDef = SymFunction("x")(t)
    end
    for i = 1:n
        try
            symXi[i] = deriv(xDef,t,i)
        catch err
            if isa(err, MethodError)
                error("Definition of x required")
            end
        end
    end
    return symXi
end

# For L, \xi needs to be contructed by hand
# xi = [x; x'; x''; ...]

# Evaluate \xi at a
function evaluate_xi(L::Union{LinearDifferentialOperator, SymLinearDifferentialOperator}, a::Number, xDef::Union{Function, Number})
    if isa(L, SymLinearDifferentialOperator)
        t = L.t
    end
    symXi = get_symXi(L, true, xDef)
    n = length(symXi)
    xiEvalA = Array{Number}(n,1)
    for i = 1:n
        xiEvalA[i,1] = evaluate(symXi[i,1],a,t)
    end
    return xiEvalA
end

# Check if U+ is valid (only works for homogeneous cases Ux=0)
function check_adjoint(L::LinearDifferentialOperator, U::VectorBoundaryForm, adjointU::VectorBoundaryForm, B::Array)
    (a,b) = L.interval
    M, N = U.M, U.N
    P, Q = (adjointU.M)', (adjointU.N)'
    BEvalA = evaluate_matrix(B, a)
    BEvalB = evaluate_matrix(B, b)
    left = M * inv(BEvalA) * P
    right = N * inv(BEvalB) * Q
    println("M * inv(BEvalA) * P")
    println(left)
    println("N * inv(BEvalB) * Q")
    println(right)
    tol = 1e-09 # Use matrix norm!
    return isapprox(left, right; atol = tol) # Can't use == to deterimine equality because left and right are arrays of floats
end

# Find a valid adjoint
function construct_valid_adjoint(L::LinearDifferentialOperator, U::VectorBoundaryForm, pDerivMatrix::Array)
    B = get_B(L, pDerivMatrix)
    BHat = get_BHat(L, B)
    Uc = get_Uc(U)
    H = get_H(U, Uc)
    J = get_J(BHat, H)
    adjointU = get_adjoint(J)
    if check_adjoint(L, U, adjointU, B)
        return adjointU
    else
        error("Adjoint found not valid")
    end
end
#############################################################################
# Tests
#############################################################################
# Test for SymLinearDifferentialOperator definition
function test_symLinearDifferentialOperator_def()
    results = [true]
    println("Testing definition of SymLinearDifferentialOperator: SymPy.Sym coefficients")
    t = symbols("t")
    passed = false
    try
        SymLinearDifferentialOperator([t+1 t+1 t+1], (0,1), t)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    println("Testing definition of SymLinearDifferentialOperator: Number coefficients")
    passed = false
    try
        SymLinearDifferentialOperator([1 1 1], (0,1), t)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    println("Testing definition of SymLinearDifferentialOperator: SymPy.Sym and Number coefficients")
    passed = false
    try
        SymLinearDifferentialOperator([1 1 t+1], (0,1), t)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: symP_k should be SymPy.Sym or Number")
    passed = false
    try
        SymLinearDifferentialOperator(['s' 1 t+1], (0,1), t)
    catch err
        if isa(err,StructDefinitionError) && err.msg == "symP_k should be SymPy.Sym or Number"
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: Only one free symbol is allowed in symP_k")
    a = symbols("a")
    passed = false
    try
        SymLinearDifferentialOperator([t+1 t+1 a*t+1], (0,1), t)
    catch err
        if isa(err,StructDefinitionError) && err.msg == "Only one free symbol is allowed in symP_k"
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    return all(results)
end
test_symLinearDifferentialOperator_def()

# Test for LinearDifferentialOperator definition
function test_linearDifferentialOperator_def()
    results = [true]
    # Variable p_k
    println("Testing definition of LinearDifferentialOperator: Function coefficients")
    t = symbols("t")
    symL = SymLinearDifferentialOperator([t+1 t+1 t+1], (1,2), t)
    passed = false
    try
        L = LinearDifferentialOperator([t->t+1 t->t+1 t->t+1], (1,2), symL)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    # Constant coefficients
    println("Testing definition of LinearDifferentialOperator: Constant coefficients represented by Numbers")
    symL = SymLinearDifferentialOperator([1 1 1], (0,1), t)
    passed = false
    try
        LinearDifferentialOperator([1 1 1], (0,1), symL)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    println("Testing definition of LinearDifferentialOperator: Constant coefficients represented by constant functions")
    symL = SymLinearDifferentialOperator([1 1 1], (0,1), t)
    passed = false
    try
        LinearDifferentialOperator([t->1 t->1 t->1], (0,1), symL)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    # Mixed coefficients
    println("Testing definition of LinearDifferentialOperator: Function and constant coefficients represented by Numbers and Functions")
    symL = SymLinearDifferentialOperator([1 1 t+1], (0,1), t)
    passed = false
    try
        LinearDifferentialOperator([1 t->1 t->t+1], (0,1), symL)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: p_k should be Function or Number")
    passed = false
    try
        LinearDifferentialOperator(['s' 1 1], (0,1), symL)
    catch err
        if err.msg == "p_k should be Function or Number" && (isa(err,StructDefinitionError))
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: Number of p_k and symP_k do not match")
    symL = SymLinearDifferentialOperator([1 1 t+1], (0,1), t)
    passed = false
    try
        LinearDifferentialOperator([1 t->1], (0,1), symL)
    catch err
        if err.msg == "Number of p_k and symP_k do not match" && (isa(err, StructDefinitionError))
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: p0 vanishes on [a,b]")
    function p2(t) return t end
    symL = SymLinearDifferentialOperator([t 1 2], (0,1), t)
    passed = false
    try
        LinearDifferentialOperator([t->t 1 2], (0,1), symL)
    catch err
        if err.msg == "p0 vanishes on [a,b]" && (isa(err, StructDefinitionError))
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)
    
    println("Testing StructDefinitionError: symP_k does not agree with p_k on [a,b]")
    symL1 = SymLinearDifferentialOperator([t+1 t+1 t+2], (0,1), t)
    passed = false
    try
        LinearDifferentialOperator([t->t+1 t->t+1 t->t+1], (0,1), symL1)
    catch err
        if err.msg == "symP_k does not agree with p_k on [a,b]" && (isa(err,StructDefinitionError))
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    return all(results)
end
test_linearDifferentialOperator_def()

# Test for VectorBoundaryForm definition
function test_vectorBoundaryForm_def()
    results = [true]
    println("Testing the definition of VectorBoundaryForm")
    M = eye(3)
    N = M
    passed = false
    try
        VectorBoundaryForm(M, N)
        passed = true
    catch err
        println("Failed with $err")
    end
    if passed
        println("Passed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: Entries of M, N should be Number")
    M = ['a' 2; 3 4]
    N = M
    passed = false
    try
        VectorBoundaryForm(M, N)
    catch err
        if err.msg == "Entries of M, N should be Number" && isa(err, StructDefinitionError)
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: M, N dimensions do not match")
    M = eye(2)
    N = eye(3)
    passed = false
    try
        VectorBoundaryForm(M, N)
    catch err
        if err.msg == "M, N dimensions do not match" && isa(err,StructDefinitionError)
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: M, N should be square matrices")
    M = [1 2]
    N = M
    passed = false
    try
        VectorBoundaryForm(M, N)
    catch err
        if err.msg == "M, N should be square matrices" && isa(err,StructDefinitionError)
            passed = true
            println("Passed!")
        else
            println("Failed with $err")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    println("Testing StructDefinitionError: Boundary operators not linearly independent")
    M = [1 2; 2 4]
    N = [3 4; 6 8]
    passed = false
    try
        VectorBoundaryForm(M, N)
    catch err
        if err.msg == "Boundary operators not linearly independent" && isa(err,StructDefinitionError)
            passed = true
            println("Passed!")
        end
    end
    if !passed
        println("Failed!")
    end
    append!(results, passed)

    return all(results)
end
test_vectorBoundaryForm_def()