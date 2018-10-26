##########################################################################################################################################################
# Date created: 2018/10/06
# Description: Quick tests along the way.
##########################################################################################################################################################
# Import packages
##########################################################################################################################################################
using SymPy
##########################################################################################################################################################
# construct_adjoint.jl
##########################################################################################################################################################
t = symbols("t")
symL = SymLinearDifferentialOperator([t+1 t+1 t+1], (0,1), t)
L = LinearDifferentialOperator([t->t+1, t->t+1, t->t+1], (0,1), symL)
symDerivMatrix = get_symPDerivMatrix(L; substitute = true)
symDerivMatrix = get_symPDerivMatrix(L; substitute = false)
pStringMatrix = get_pStringMatrix(L)
u, v = SymFunction("u")(t), SymFunction("v")(t)
symUVForm = get_symUvForm(L, u, v; substitute = true)
symUVForm = get_symUvForm(L, u, v; substitute = false)
pDerivMatrix = [t->t+1 t->t; t->t+1 t->t]
B = get_B(L; pDerivMatrix = pDerivMatrix)
symB = get_B(L; symbolic = true)
symB = get_B(L; symbolic = true, substitute = false)
BHat = get_BHat(L, B)
symXi = get_symXi(L; substitute = true, xDef = t^2+2)
evaluate_xi(L, 1, symXi)
xi = [t->t^2+2; t->2t]
evaluate_xi(L, 1, xi)
U = VectorBoundaryForm([1 2; 3 4], [4 3; 2 1])
get_boundaryCondition(L, U, symXi)
get_boundaryCondition(L, U, xi)

t = symbols("t")
symL = SymLinearDifferentialOperator([t+1 t+1 t+1], (0,1), t)
L = LinearDifferentialOperator([t->t+1, t->t+1, t->t+1], (0,1), symL)
symDerivMatrix = get_symPDerivMatrix(L; substitute = true)
symDerivMatrix = get_symPDerivMatrix(L; substitute = false)
pStringMatrix = get_pStringMatrix(L)
u, v = SymFunction("u")(t), SymFunction("v")(t)
symUVForm = get_symUvForm(L, u, v; substitute = true)
symUVForm = get_symUvForm(L, u, v; substitute = false)
symB = get_symB(L; substitute = true)
symB = get_symB(L; substitute = false)
pDerivMatrix = [t->t+1 t->t; t->t+1 t->t]
B = get_B(L, pDerivMatrix)
BHat = get_BHat(L, B)
symXi = get_symXi(L; substitute = true, xDef = t^2+2)
evaluate_xi(L, 1, symXi)
xi = [t->t^2+2; t->2t]
evaluate_xi(L, 1, xi)
U = VectorBoundaryForm([1 2; 3 4], [4 3; 2 1])
get_boundaryCondition(L, U, symXi)
get_boundaryCondition(L, U, xi)

# Real pFunctions and M, N
t = symbols("t")
(a,b) = (0,1)
symPFunctions = [t+1 2t t]
pFunctions = [t->t+1 t->2t t->t]
symL = SymLinearDifferentialOperator(symPFunctions, (a,b), t)
L = LinearDifferentialOperator(pFunctions, (a,b), symL)
n = 2
MCand = rand(Uniform(1.0,10.0), n, n)
NCand = rand(Uniform(1.0,10.0), n, n)
U = VectorBoundaryForm(MCand, NCand)
pDerivMatrix = [t->t+1 t->1; t->2t t->2]
construct_validAdjoint(L, U, pDerivMatrix)

# Real pFunctions, complex M, N
t = symbols("t")
(a,b) = (0,1)
symPFunctions = [t+1 2t t]
pFunctions = [t->t+1 t->2t t->t]
symL = SymLinearDifferentialOperator(symPFunctions, (a,b), t)
L = LinearDifferentialOperator(pFunctions, (a,b), symL)
n = 2
MCandRe = rand(Uniform(1.0,10.0), n, n)
MCandIm = rand(Uniform(1.0,10.0), n, n)
MCand = MCandRe + MCandIm*im
NCandRe = rand(Uniform(1.0,10.0), n, n)
NCandIm = rand(Uniform(1.0,10.0), n, n)
NCand = NCandRe + NCandIm*im
U = VectorBoundaryForm(MCand, NCand)
pDerivMatrix = [t->t+1 t->1; t->2t t->2]
construct_validAdjoint(L, U, pDerivMatrix)

# Complex pFunctions, real M, N
t = symbols("t")
(a,b) = (0,1)
symPFunctions = [t+im t*im t]
pFunctions = [t->t+im t->t*im t->t]
symL = SymLinearDifferentialOperator(symPFunctions, (a,b), t)
L = LinearDifferentialOperator(pFunctions, (a,b), symL)
n = 2
MCand = rand(Uniform(1.0,10.0), n, n)
NCand = rand(Uniform(1.0,10.0), n, n)
U = VectorBoundaryForm(MCand, NCand)
pDerivMatrix = [t->t+im t->t; t->t*im t->im]
construct_validAdjoint(L, U, pDerivMatrix)
B = get_B(L; pDerivMatrix = pDerivMatrix)
BHat = get_BHat(L, B)
Uc = get_Uc(U)
H = get_H(U, Uc)
J = get_J(BHat, H)
adjointU = get_adjoint(J)
n = convert(Int, size(J)[1]/2)
Pstar = J[(n+1):2n,1:n]
Qstar = J[(n+1):2n, (n+1):2n]
adjoint = VectorBoundaryForm(Pstar, Qstar)
rank(hcat(Pstar, Qstar))
Pstar
rank(Pstar)
A = [Pstar[1] Pstar[2]; Pstar[3] Pstar[4]]
rank(A)
B = Matrix(vec(Pstar), 2, 2)
rank(B)
M = Array{Complex}(2,2)
N = Array{Complex}(2,2)
M = Array{Number}(2,2)
N = Array{Number}(2,2)
M = convert(Array{Complex}, Pstar)
for i = 1:length(Pstar)
    M[i] = Pstar[i]
end
for i = 1:length(Qstar)
    N[i] = Qstar[i]
end

# Complex pFunctions and M, N
t = symbols("t")
(a,b) = (0,1)
symPFunctions = [t+im t*im t]
pFunctions = [t->t+im t->t*im t->t]
symL = SymLinearDifferentialOperator(symPFunctions, (a,b), t)
L = LinearDifferentialOperator(pFunctions, (a,b), symL)
n = 2
MCandRe = rand(Uniform(1.0,10.0), n, n)
MCandIm = rand(Uniform(1.0,10.0), n, n)
MCand = MCandRe + MCandIm*im
NCandRe = rand(Uniform(1.0,10.0), n, n)
NCandIm = rand(Uniform(1.0,10.0), n, n)
NCand = NCandRe + NCandIm*im
U = VectorBoundaryForm(MCand, NCand)
pDerivMatrix = [t->t+im t->t; t->t*im t->im]
construct_validAdjoint(L, U, pDerivMatrix)

##########################################################################################################################################################
# transformPairs.jl
##########################################################################################################################################################
t = symbols("t")
(a,b) = (0,1)
symPFunctions = [t+im t*im t]
pFunctions = [t->t+im t->t*im t->t]
symL = SymLinearDifferentialOperator(symPFunctions, (a,b), t)
L = LinearDifferentialOperator(pFunctions, (a,b), symL)
n = 2
MCandRe = rand(Uniform(1.0,10.0), n, n)
MCandIm = rand(Uniform(1.0,10.0), n, n)
MCand = MCandRe + MCandIm*im
NCandRe = rand(Uniform(1.0,10.0), n, n)
NCandIm = rand(Uniform(1.0,10.0), n, n)
NCand = NCandRe + NCandIm*im
U = VectorBoundaryForm(MCand, NCand)
pDerivMatrix = [t->t+im t->t; t->t*im t->im]
adjointU = construct_validAdjoint(L, U, pDerivMatrix)

lambda = 1.5
(MPlus, MMinus) = get_MPlusMinus(adjointU, lambda)
M = get_M(adjointU, lambda)
f(x) = x
(FPlus, FMinus) = get_FPlusMinus(adjointU, f, lambda)

f(x) = exp(-im*x)*(3x^2+cos(x)+1)
fChebApproxSym = get_ChebyshevApproximation(f, 0, 1; symbolic = true)
(subs(fChebApproxSym[1], free_symbols(fChebApproxSym[1]), 0))(0)
fChebApprox = get_ChebyshevApproximation(f, 0, 1; symbolic = false)
fChebApprox(0)


integrate(t^2 * exp(t) * cos(t), t)
integrate(exp(-im*t)*(3t^2+cos(t)+1), t)
integrate(exp(-im*t)*(3t^2+cos(t)+1), (t,0,1))
SymPy.integrate(exp(-im*t)*(3t^2+cos(t)+1), (t,0,im))
6*e^(-im) - 2*im*e^(-im) + (e^(-im)*sin(1))/2 + (e^(-im)*cos(1))/2 + (im*e^(-im)*sin(1))/2 + 5*im
g(x) = e^(-im*x)*(3x^2+cos(x)+1)
quadgk(g, 0, 1)
quadgk(g, 0, im)

f(x) = e^(-im*x)*(3x^2+cos(x)+1)
cF = Fun(f, 0..1)
cF(1)
fChebApproxSym = get_ChebyshevApproximation(f, 0, 1; symbolic = true)
fChebApproxSym[2]
N(fChebApproxSym[2](1))
fChebApprox = get_ChebyshevApproximation(f, 0, 1; symbolic = false)
fChebApprox(1)

cF = Fun(f, (-1)..1)
cF(0)
fChebApproxSym = get_ChebyshevApproximation(f, -1, 1; symbolic = true)
fChebApproxSym[2]
N(fChebApproxSym[2](0))
fChebApprox = get_ChebyshevApproximation(f, -1, 1; symbolic = false)
fChebApprox(0)


cF = Fun(f, 2..3)
cF(2)
fChebApproxSym = get_ChebyshevApproximation(f, 2, 3; symbolic = true)
fChebApproxSym[3]
N(fChebApproxSym[3](2))
fChebApprox = get_ChebyshevApproximation(f, 2, 3; symbolic = false)
fChebApprox(2)

cF = Fun(f, (-2)..(-1))
cF(-1)
fChebApproxSym = get_ChebyshevApproximation(f, -2, -1; symbolic = true)
fChebApproxSym[1]
N(fChebApproxSym[1](-1))
fChebApprox = get_ChebyshevApproximation(f, -2, -1; symbolic = false)
fChebApprox(-1)