# ############################################################################
# #
# #  (c) Copyright 2024 Fair Isaac Corporation
# #
# #    Licensed under the Apache License, Version 2.0 (the "License");
# #    you may not use this file except in compliance with the License.
# #    You may obtain a copy of the License at
# #
# #      
# http://www.apache.org/licenses/LICENSE-2.0
# #
# #    Unless required by applicable law or agreed to in writing, software
# #    distributed under the License is distributed on an "AS IS" BASIS,
# #    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# #    See the License for the specific language governing permissions and
# #    limitations under the License.
# #
# ############################################################################
using XpressAPI

# Note: To run this example, a global solver license is required.

#=
The inscribed square problem, also known as the square peg problem or the Toeplitz' conjecture, is an unsolved question in geometry: Does every plane simple closed curve contain all four vertices of some square?
This is true if the curve is convex or piecewise smooth and in other special cases.
The problem was proposed by Otto Toeplitz in 1911. See also https://en.wikipedia.org/wiki/Inscribed_square_problem
This instance computes a maximal inscribing square for the curve (sin(t)*cos(t), sin(t)*t), t in [-π,π].
Model was contributed to MINLPlib by Benjamin Müller and Felipe Serrano
=#

XPRScreateprob("") do prob

if XPRSfeaturequery("Global") != 1
  error("A global solver license is required")
end

XPRSaddcbmessage(prob, (p, m, l, t) -> if l > 0 println(": ", m); end, 0)

# add variables
obj = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
lb = [-Inf, -π, -π, -π, -π, -Inf, -Inf, 0.0, 0.0]
ub = [Inf, π, π, π, π, Inf, Inf, Inf, Inf]
XPRSaddcols(prob, 9, 0, obj, [0, 0], Int32[], Float64[], lb, ub)
XPRSaddnames(prob, 2, ["objvar", "t1", "t2", "t3", "t4", "x1", "y1", "len", "height"], 0, 8)

#add linear parts of rows
rowtype = ['E' for i in 1:17]
rhs = [0.0 for i in 1:9]
rng = [0.0 for i in 1:9]
start = [0, 1, 2, 3, 5, 7, 9, 11, 14]
colind = [0, 5, 6, 5, 7, 6, 8, 5, 8, 6, 7, 5, 7, 8, 6, 7, 8]
rowcoef = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0 , -1.0, -1.0, 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, -1.0, -1.0]
XPRSaddrows(prob, 9, 17, rowtype, rhs, rng, start, colind, rowcoef)

#add formulas
rowind = [0, 1, 2, 3, 4, 5, 6, 7, 8]
formulastart = [0, 8, 16, 22, 30, 36, 44, 50, 58, 64]
type = [XPRS_TOK_COL, XPRS_TOK_CON, XPRS_TOK_OP, XPRS_TOK_COL, XPRS_TOK_CON, XPRS_TOK_OP, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_COL, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_COL, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_COL, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_OP, XPRS_TOK_EOF,  XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_IFUN, XPRS_TOK_COL, XPRS_TOK_OP, XPRS_TOK_EOF]
value = [7, 2, XPRS_OP_EXPONENT, 8, 2, XPRS_OP_EXPONENT, XPRS_OP_PLUS, 0.0,  0.0, 1, XPRS_IFUN_SIN, 0.0, 1, XPRS_IFUN_COS, XPRS_OP_MULTIPLY, 0.0,  0.0, 1, XPRS_IFUN_SIN, 1, XPRS_OP_MULTIPLY, 0.0,  0.0, 2, XPRS_IFUN_SIN, 0.0, 2, XPRS_IFUN_COS, XPRS_OP_MULTIPLY, 0.0,  0.0, 2, XPRS_IFUN_SIN, 2, XPRS_OP_MULTIPLY, 0.0,  0.0, 3, XPRS_IFUN_SIN, 0.0, 3, XPRS_IFUN_COS, XPRS_OP_MULTIPLY, 0.0,  0.0, 3, XPRS_IFUN_SIN, 3, XPRS_OP_MULTIPLY, 0.0,  0.0, 4, XPRS_IFUN_COS, 0.0, 4, XPRS_IFUN_SIN, XPRS_OP_MULTIPLY, 0.0,  0.0, 4, XPRS_IFUN_SIN, 4, XPRS_OP_MULTIPLY, 0.0]
XPRSnlpaddformulas(prob, 9, rowind, formulastart, 1, type, value)
XPRSwriteprob(prob, "inscribedsquare.lp", "l")

#set initial values
initvalind = [i for i in 0:8]
initval = [0.0, -π, -π/2, 0, -π/2, 1, 1, 0, 0]
XPRSnlpsetinitval(prob, 9, initvalind, initval)

#solve problem to local optimality
XPRSsetintcontrol(prob, XPRS_NLPPRESOLVE, 0)
solvestatus, solstatus = XPRSoptimize(prob, "")
@assert solvestatus == XPRS_SOLVESTATUS_COMPLETED
@assert (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)

#read solution
objval = XPRSgetdblattrib(prob, XPRS_NLPOBJVAL)
_, sol = XPRSgetsolution(prob, XPRS_ALLOC, 0, 8)
println(objval)
println(sol[1])
println("local solution: objvar: $(sol[1]), t1: $(sol[2]), t2: $(sol[3]), t3: $(sol[4]), t4: $(sol[5]), x1: $(sol[6]) y1: $(sol[7]), len: $(sol[8]), height: $(sol[9])")

#solve problem to global optimality
states = XPRSoptimize(prob, "x")
@assert solvestatus == XPRS_SOLVESTATUS_COMPLETED
@assert (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)

#read solution
objval = XPRSgetdblattrib(prob, XPRS_NLPOBJVAL)
_, sol = XPRSgetsolution(prob, XPRS_ALLOC, 0, 8)
println("global solution: objvar: $(sol[1]), t1: $(sol[2]) t2: $(sol[3]), t3: $(sol[4]), t4: $(sol[5]), x1: $(sol[6]), y1: $(sol[7]), len: $(sol[8]), height: $(sol[9])")
end