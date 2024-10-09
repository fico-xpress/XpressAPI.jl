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
import JSON
using Random
using XpressAPI
using Test, TestReports
@testset "xprs_cannery" begin
  println("Run test xprs_cannery")
  
  # This is the cannery example from the JUMP tutorial
  
  XPRScreateprob("") do prob
  	XPRSaddcbmessage(prob, (p, m, l, t) -> if l > 0 println(": ", m); end, 0)
  	data = JSON.parse("""
  {
      "plants": {
          "Seattle": {"capacity": 350},
          "San-Diego": {"capacity": 600}
      },
      "markets": {
          "New-York": {"demand": 300},
          "Chicago": {"demand": 300},
          "Topeka": {"demand": 300}
      },
      "distances": {
          "Seattle => New-York": 2.5,
          "Seattle => Chicago": 1.7,
          "Seattle => Topeka": 1.8,
          "San-Diego => New-York": 2.5,
          "San-Diego => Chicago": 1.8,
          "San-Diego => Topeka": 1.4
      }
  }
  """)
    P = keys(data["plants"])
    M = keys(data["markets"])
    #create variables and objective
    distance(p::String, m::String) = data["distances"]["$(p) => $(m)"]
    obj = vec([distance(p,m) for m in M, p in P])
    lb = [0.0 for i in 0:5]
    ub = [Inf for i in 0:5]
    XPRSaddcols(prob, 6, 0, obj, [0, 0], Int32[], Float64[], lb, ub)
    #add variable names
    ind = 0
    for p in P, m in M
  	  XPRSaddnames(prob, 2, ["Transport" * p * "=>" * m], ind, ind)
  	  ind = ind + 1
    end
    #create supply constraints
    ind = 0
    for p in P
  	  rowtype = ['L' for m in M]
  	  rhs = [data["plants"][p]["capacity"]]
  	  colind = [ind*length(M) + m for m in 0:length(M)-1]
  	  coefs = [1.0 for m in M]
  	  XPRSaddrows(prob, 1, length(M), rowtype, rhs, Float64[], [0], colind, coefs)
  	  ind = ind+1
    end
    #create demand constraints
    ind = 0
    for m in M
  	  rowtype = ['G' for m in M]
  	  rhs = [data["markets"][m]["demand"]]
  	  colind = [p*length(M) + ind for p in 0:length(P)-1]
  	  coefs = [1.0 for p in P]
  	  XPRSaddrows(prob, 1, length(P), rowtype, rhs, Float64[], [0], colind, coefs)
  	  ind = ind+1
    end
    XPRSwriteprob(prob, "xprs_test2.lp", "l");
  
    solvestatus, solstatus = XPRSoptimize(prob, "")
    @test solvestatus == XPRS_SOLVESTATUS_COMPLETED
    @test (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)
    ind = 0
    for p in P, m in M
  	  solval = XPRSgetlpsolval(prob, ind, 0)
  	  println("Transport" * p * "=>" * m * ": " * string(solval[1]))
  	  ind = ind + 1
    end
  end

end
@testset "xprs_inscribedsquare" begin
  println("Run test xprs_inscribedsquare")
  
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
  @test solvestatus == XPRS_SOLVESTATUS_COMPLETED
  @test (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)
  
  #read solution
  objval = XPRSgetdblattrib(prob, XPRS_NLPOBJVAL)
  _, sol = XPRSgetsolution(prob, XPRS_ALLOC, 0, 8)
  println(objval)
  println(sol[1])
  println("local solution: objvar: $(sol[1]), t1: $(sol[2]), t2: $(sol[3]), t3: $(sol[4]), t4: $(sol[5]), x1: $(sol[6]) y1: $(sol[7]), len: $(sol[8]), height: $(sol[9])")
  
  #solve problem to global optimality
  states = XPRSoptimize(prob, "x")
  @test solvestatus == XPRS_SOLVESTATUS_COMPLETED
  @test (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)
  
  #read solution
  objval = XPRSgetdblattrib(prob, XPRS_NLPOBJVAL)
  _, sol = XPRSgetsolution(prob, XPRS_ALLOC, 0, 8)
  println("global solution: objvar: $(sol[1]), t1: $(sol[2]) t2: $(sol[3]), t3: $(sol[4]), t4: $(sol[5]), x1: $(sol[6]), y1: $(sol[7]), len: $(sol[8]), height: $(sol[9])")
  end
end
@testset "xprs_markshare" begin
  println("Run test xprs_markshare")
  """Illustrate how to use branching callback with Xpress.
  
  We create MIPLIB problem markshare1 as Xpress needs a lot of nodes to
  solve this problem. So we can be sure our branch callback actually
  gets invoked.
  
  In the branching callback we just find the most fractional binary variable
  and branch on that.
  """
  
  XPRScreateprob("") do prob
    solvestatus, solstatus = Nothing, Nothing
    XPRSaddcbmessage(prob, (p, m, l, t) -> if l > 0 println(": ", m); end, 0)
    XPRSaddrows(prob, 6, 0,
                [ 'E', 'E', 'E', 'E', 'E', 'E' ],       # rowtype
                [ 1116, 1325, 1353, 1169, 1160, 1163 ], # rhs
                Float64[],                              # range
                zeros(Int32, 7),                        # start
                Int32[],                                # colind
                Float64[])                              # rowcoef
    XPRSaddcols(prob, 62, 312,
        # obj
        [ 1, -1, 1, -1, 1, -1, 1, -1,
          1, -1, 1, -1, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0 ],
        # start
        [ 0, 1, 2, 3, 4, 5, 6, 7,
          8, 9, 10, 11, 12, 18, 24, 30,
          36, 42, 48, 54, 60, 66, 72, 78,
          84, 90, 96, 102, 108, 114, 120, 126,
          132, 138, 144, 150, 156, 162, 168, 174,
          180, 186, 192, 198, 204, 210, 216, 222,
          228, 234, 240, 246, 252, 258, 264, 270,
          276, 282, 288, 294, 300, 306, 312 ],
        # rowind
        [ 0, 0, 1, 1, 2, 2, 3, 3,
          4, 4, 5, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5,
          0, 1, 2, 3, 4, 5, 0, 1,
          2, 3, 4, 5, 0, 1, 2, 3,
          4, 5, 0, 1, 2, 3, 4, 5 ],
        # rowcoef
        [ 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 25, 97, 95, 1,
          3, 69, 35, 64, 71, 27, 94, 72,
          14, 24, 19, 46, 51, 94, 76, 63,
          15, 48, 4, 56, 58, 58, 66, 66,
          25, 90, 10, 45, 76, 58, 46, 20,
          20, 20, 4, 52, 30, 56, 51, 71,
          50, 6, 2, 50, 58, 32, 50, 14,
          89, 79, 1, 7, 97, 26, 65, 59,
          35, 28, 83, 55, 28, 36, 40, 77,
          14, 61, 46, 24, 65, 95, 27, 60,
          36, 42, 59, 96, 14, 3, 53, 9,
          24, 70, 34, 33, 30, 29, 44, 22,
          9, 99, 73, 68, 1, 93, 99, 36,
          37, 10, 93, 32, 62, 55, 60, 1,
          24, 17, 92, 70, 21, 44, 68, 56,
          39, 73, 41, 74, 38, 74, 56, 70,
          2, 61, 64, 62, 53, 38, 21, 37,
          93, 94, 91, 66, 93, 71, 14, 9,
          81, 39, 82, 63, 83, 92, 46, 43,
          16, 44, 6, 90, 94, 63, 97, 77,
          58, 40, 76, 88, 75, 57, 14, 45,
          53, 47, 50, 46, 71, 84, 58, 18,
          13, 51, 17, 62, 23, 73, 43, 43,
          18, 62, 15, 40, 45, 4, 8, 34,
          63, 91, 64, 85, 57, 21, 2, 96,
          78, 59, 48, 2, 31, 49, 78, 7,
          35, 75, 55, 13, 6, 25, 13, 42,
          71, 27, 35, 46, 47, 75, 97, 22,
          72, 25, 46, 29, 71, 71, 31, 70,
          8, 4, 55, 99, 28, 78, 82, 64,
          8, 66, 56, 88, 51, 80, 57, 57,
          60, 20, 49, 17, 14, 1, 23, 40,
          85, 55, 76, 54, 70, 40, 66, 73,
          1, 35, 46, 16, 45, 23, 46, 52,
          88, 3, 99, 13, 87, 66, 20, 3,
          21, 91, 22, 26, 69, 5, 75, 70,
          97, 1, 13, 77, 78, 73, 99, 26,
          40, 88, 43, 28, 92, 12, 73, 16 ],
        # lb
        [ 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0 ],
        # ub
        [ 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1 ])
    XPRSchgcoltype(prob, 62, [i for i in 0:61],
      [ 'C', 'C', 'C', 'C', 'C', 'C', 'C', 'C', 'C', 'C', 'C', 'C', 'B', 'B', 'B',
        'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
        'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
        'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
        'B', 'B' ])
    XPRSsetintcontrol(prob, XPRS_MAXNODE, 100)
    XPRSaddcbchgbranchobject(prob, (p, b) -> begin
      x, _, _, _ = XPRSgetlpsol(p, XPRS_ALLOC, nothing, nothing, nothing)
      # Go through the binary variables and find the most fractional one
      maxfrac = 0.0
     maxvar = -1
      for i in 12:61
        r = abs(x[i+1] - round(x[i+1]))
        if r > maxfrac
          maxfrac = r
          maxvar = i
        end
      end
      if maxvar >= 0
        println("Branching on $(maxvar), value $(x[maxvar+1]), fractionality $(maxfrac)")
        mybranch = XPRS_bo_create(p, true)
        XPRS_bo_addbranches(mybranch, 2)
        XPRS_bo_addbounds(mybranch, 0, 1, ['U'], [maxvar], [0.0])
        XPRS_bo_addbounds(mybranch, 1, 1, ['L'], [maxvar], [1.0])
        return mybranch
      else
        return b
      end
    end, 0)
    solvestatus, solstatus = XPRSoptimize(prob, "")
    @test solvestatus != XPRS_SOLVESTATUS_COMPLETED
    @test (solstatus != XPRS_SOLSTATUS_OPTIMAL) || (solstatus != XPRS_SOLSTATUS_FEASIBLE)
  end
end
@testset "xprs_nonconvexqcp" begin
  println("Run test xprs_nonconvexqcp")
  
  # Note: To run this example, a global solver license is required.
  
  #=
  Minimize
    obj: x + y
    
  Subject To
    q1: [2 x^2 + y^2 ] >= 4
  
  Bounds
  x <= 5
  y <= 5
  =#
  
  XPRScreateprob("") do prob
    if XPRSfeaturequery("Global") != 1
      error("A global solver license is required")
    end
    XPRSaddcbmessage(prob, (p, m, l, t) -> if l > 0 println(": ", m); end, 0)
    obj = [1.0 for i in 0:1]
    lb = [0.0 for i in 0:1]
    ub = [5.0 for i in 0:1]
    XPRSaddcols(prob, 2, 0, obj, [0, 0], Int32[], Float64[], lb, ub)
    XPRSaddrows(prob, 1, 0, ['G'], [4.0], [0.0], Int32[], Int32[], Float64[])
    XPRSaddqmatrix(prob, 0, 2, [0, 1], [0, 1], [2.0, 1.0])
    XPRSwriteprob(prob, "trivialnonconvexqcp.lp", "l")
    solvestatus, solstatus = XPRSoptimize(prob, "x")
    @test solvestatus == XPRS_SOLVESTATUS_COMPLETED
    @test (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)
  end

end
@testset "xprs_tsp" begin
  println("Run test xprs_tsp")
  """
  # Travelling Salesman Problem
  
  Solves the classic travelling salesman problem as a MIP,
  where sub-tour elimination constraints are added
  only as needed during the branch-and-bound search.
  
  Demonstrates:
  - Loading of an initial, feasible MIP solution.
  - Adding external constraints during branch-and-bound.
  
  The example also illustrates how array indices in Julia are 1-based while
  row and column indices in Xpress are 0-based.
  
  (c) 2022-2024 Fair Isaac Corporation
  """
  
  """Number of cities to visit.
  
  Make sure this is small when SUBTOUR_TYPES is 0 or 1."""
  NUM_CITIES = 30
  
  """Maximum magnitude of each coordinate.
  
  The coordinates for the nodes in our TSP
  are drawn at random from this range."""
  MAX_COORD = 100
  
  """How to handle subtour elimination constraints.
  
  - `0`: normal rows
  - `1`: delayed rows
  - `2`: cuts
  """
  SUBTOUR_TYPES = 2
  
  
  """Create a feasible tour and add this as initial MIP solution."""
  function CreateInitialTour(prob)
    tour = zeros(Int32, NUM_CITIES*NUM_CITIES)
  
    # Create a tour that visits all cities in order.
    for i in 1:NUM_CITIES-1
      # Travel from each city i to city i+1...
      tour[1 + (i-1)*NUM_CITIES + (i-1) + 1] = 1.0
    end
    # ... and complete the tour.
    tour[1 + (NUM_CITIES-1)*NUM_CITIES + 0] = 1.0
  
    XPRSaddmipsol(prob, NUM_CITIES * NUM_CITIES, tour, Int32[], "init_tour")
  end
  
  """Load the TSP problem formulation into the Xpress problem structure.
  
  This only creates the constraints that make sure each city is entered
  and left exactly once.
  The constraints that ensure there is no subtour are created either in
  AddSubtourEliminationConstraints() or are dynamically separated in
  the cbOptNode() callback.
  """
  function CreateTSPProblem(prob)
    dist = Vector{Float64}(undef, NUM_CITIES*NUM_CITIES) # distance matrix
    xLoc = Vector{Float64}(undef, NUM_CITIES)            # x-coordinate of nodes
    yLoc = Vector{Float64}(undef, NUM_CITIES)            # y-coordinate of nodes
    visitCoef = Vector{Float64}(undef, NUM_CITIES)       # buffer for a row's non-zero values
    visitIdx = Vector{Int32}(undef, NUM_CITIES)          # buffer for a row's non-zero indices
  
    # Sprinkle cities randomly in the plane.
    Random.seed!(0)
    for i in 1:NUM_CITIES
      xLoc[i] = MAX_COORD * rand()
      yLoc[i] = MAX_COORD * rand()
    end
    # Calculate the distance matrix.
    # Our problem is symmetric, so the distance (i,j) is the same as (j,i)
    for i in 1:NUM_CITIES
      dist[(i-1)*NUM_CITIES + i] = 0.0
      for j in 1:NUM_CITIES
        d = sqrt((xLoc[i] - xLoc[j])^2 + (yLoc[i] - yLoc[j])^2)
        dist[(i-1)*NUM_CITIES + j] = d
        dist[(j-1)*NUM_CITIES + i] = d
      end
    end
  
    # Create the variables, which are binaries that indicate if we travel from
    # city i to city j in our tour.
    # The trip (i->j) will have column index (i-1)*NUM_CITIES+(j-1).
    for i in 1:NUM_CITIES
      for j in 1:NUM_CITIES
        # Add the binary representing the trip (i->j) with an objective of
        # minimizing total distance. */
        colIdx = (i-1)*NUM_CITIES + (j-1)
        XPRSaddcols(prob, 1, 0, [dist[1 + colIdx]], [0, 0], Int32[], Float64[],
                    [0], [1.0])
        XPRSaddnames(prob, XPRS_NAMES_COLUMN, ["travel($(i),$(j))"], colIdx, colIdx)
        XPRSchgcoltype(prob, 1, [colIdx], ['B'])
        if i == j
          XPRSchgbounds(prob, 1, [colIdx], ['U'], [0.0])
        end
      end
    end
  
    # Create constraints to ensure that each city is visited only once.
    for i in 1:NUM_CITIES
      # Create a constraint to ensure that we leave each city exactly once.
      XPRSaddrows(prob, 1, NUM_CITIES-1, ['E'], [1.0], Float64[], [0, NUM_CITIES-1],
                  [(i-1)*NUM_CITIES + (j-1) for j in 1:NUM_CITIES if j != i],
                  ones(Float64, NUM_CITIES-1))
      # Create a constraint to ensure that we enter each city exactly once.
      XPRSaddrows(prob, 1, NUM_CITIES-1, ['E'], [1.0], Float64[], [0, 0],
                  [(j-1)*NUM_CITIES + (i-1) for j in 1:NUM_CITIES if j != i],
                  ones(Float64, NUM_CITIES-1))
    end
  end
  
  """Adds the exponential number of subtour elimination constraints.
  
  We split the set of all cities S into two disjoint sets (T, S\\T) and create
  constraints that require that we travel at least once from the set T to the
  set S\\T.
  
  This simple implementation has complexity O(n^2*2^n), where n=NUM_CITIES,
  so make sure to run it for tiny values of NUM_CITIES only.
  """
  function AddSubtourEliminationConstraints(prob, useDelayedRows)
    # Enumerate all possible subtours.
    isMember = zeros(Int32, NUM_CITIES)
    visitIdx = Vector{Int32}(undef, NUM_CITIES)
    visitCoef = ones(Float64, NUM_CITIES)
    while true
      k = 0
      isMember[1] += 1
      while isMember[k+1] > 1
        isMember[k+1] = 0
        isMember[k+1 + 1] += 1
        k += 1
      end
  
      # Check that we haven't enumerated all possibilities.
      numMembers = 0
      for i in 1:NUM_CITIES
        numMembers += isMember[i]
      end
      if numMembers == NUM_CITIES
        break
      end
  
      # We don't need to create constraints for subsets containing more than
      # half the cities, due to symmetries.
      if numMembers > NUM_CITIES / 2
        continue
      end
  
      # Create the sub-tour elimination constraint.
      nCoef = 0
      for i in 1:NUM_CITIES
        if !isMember[i]
          continue
        end
        for j in 1:NUM_CITIES
          if isMember[j]
            continue
          end
          nCoef += 1
          visitCoef[nCoef] = 1.0
          visitIdx[nCoef] = (i-1)*NUM_CITIES + (j-1)
        end
      end
      XPRSaddrows(prob, 1, nCoef, ['G'], [1.0], nothing, [0, ncoef],
                  visitIdx, visitCoef)
      # If delayed rows are requested then mark the row we just created
      # as delayed row.
      if useDelayedRows
        XPRSloaddelayedrows(prob, 1, [ XPRSgetintattrib(prob, XPRS_ROWS) - 1])
      end
    end
  end
  
  """Callback function used for catching solutions that contain
     invalid subtours.
  
  This callback is invoked before an integer solution is accepted. It gives
  us a chance to reject the solution by returning true as first return value.
  In case solType is 0 (zero), we can even add cuts that cut off infeasible
  solutions.
  """
  function cbPreIntSol(prob, solType, cutoff)
    reject = false
    # Get the current binary solution and translate it into a tour.
    mipSol, _, _, _ = XPRSgetlpsol(prob, XPRS_ALLOC, nothing, nothing, nothing)
    nextCity = repeat([-1], NUM_CITIES)
    for i in 1:NUM_CITIES
      for j in 1:NUM_CITIES
        if mipSol[1 + (i-1)*NUM_CITIES + (j-1)] > 0.5
          nextCity[i] = j
        end
      end
    end
    # Count the number of cities in the first tour.
    numCities = 1
    i = 1
    while nextCity[i] != 1
      numCities += 1
      i = nextCity[i]
    end
    reject = false
    if numCities < NUM_CITIES
      # The tour given by the current solution does not pass through
      # all the nodes and is thus infeasible.
      # If soltype is non-zero then we reject by setting reject=true.
      # If instead soltype is zero then the solution came from an
      # integral node. In this case we can reject by adding a cut
      # that cuts off that solution. Note that we must NOT set
      # rejecttTrue in that case because that would result in just
      # dropping the node, no matter whether we add cuts or not.
      println("Reject infeasible solution.")
  	if solType != 0
  	  reject = true
  	else
        # The solution came from an integral node. We can add subtour elimination
  	  # contraints to cut off this solution.
        cutIdx = Vector{Int32}(undef, NUM_CITIES * NUM_CITIES)
        cutCoef = Vector{Float64}(undef, NUM_CITIES * NUM_CITIES)
        colind = Vector{Int32}(undef, NUM_CITIES * NUM_CITIES)
        rowcoef = Vector{Float64}(undef, NUM_CITIES * NUM_CITIES)
  
        # Create a subtour elimination cut for each subtour.
        for k in 1:NUM_CITIES
          # Skip subtours we have already checked.
          if nextCity[k] == -1
            continue
  		end
  
          # Identify which cities are part of the subtour.
          isTour = zeros(Bool, NUM_CITIES)
          numCities = 0
          j = k
          while true
            i = nextCity[j]
            isTour[j] = true
            numCities += 1
            nextCity[j] = -1
            j = i
            nextCity[j] >= 0 || break
          end
  
          # Create a subtour elimination cut.
          numCoef = 0
          for i in 1:NUM_CITIES
            if !isTour[i]
              continue
            end
            for j in 1:NUM_CITIES
              if isTour[j]
                continue
              end
              numCoef += 1
              cutCoef[numCoef] = 1.0
              cutIdx[numCoef] = (i-1)*NUM_CITIES + (j-1)
            end
          end
  
          # Before adding the cut, we must translate it to the presolved model.
          # If this translation fails then we cannot continue. The translation
          # can only fail if we have presolve operations enabled that should be
          # disabled in case of dynamically separated constraints. */
          coefs, _, _, rhs, status = XPRSpresolverow(prob, 'G', numCoef, cutIdx, cutCoef, 1.0,
                                        NUM_CITIES*NUM_CITIES, colind, rowcoef)
          if status != 0
            error("Possible presolve operation prevented the proper translation of a subtour constraint, with status $(status)")
          end
          XPRSaddcuts(prob, 1, [1], ['G'], [rhs], [0, coefs], colind, rowcoef)
        end
      end
    else
      println("Accept solution:")
      PrintSolution(mipSol)
    end
    return reject, nothing # return nothing as `cutoff` to keep Xpress's cutoff
  end
  
  """Print the current MIP solution."""
  function PrintSolution(mipSol)
    nextCity = repeat([-1], NUM_CITIES)
    for i in 1:NUM_CITIES
      for j in 1:NUM_CITIES
        if mipSol[1 + (i-1)*NUM_CITIES + (j-1)] > 0.5
          nextCity[i] = j
        end
      end
    end
  
    print("Tour: 0")
    i = 1
    while true
      i = nextCity[i]
      print(" -> $(i-1)")
      if i == 1
        break
      end
    end
    println()
  end
  
  XPRScreateprob("") do prob
  
    XPRSaddcbmessage(prob, (p, m, l, t) -> if l > 0 println(": ", m); end, 0)
  
    # Create a new problem and immediately register a message handler.
    # Once we have a message handler installed, errors will produce verbose
    # error messages on the console and we can limit ourselves to minimal
    # error handling in the code here.
  
    CreateTSPProblem(prob)
  
    if SUBTOUR_TYPES <= 1
      #Add all subtour elimination constraints from the start.
      AddSubtourEliminationConstraints(prob, (SUBTOUR_TYPES == 1))
    else
      # We are going to create our subtour elimination constraints dynamically
      # during the solve, so ...
      # ... disable any presolve operations that conflict with not having the
      #     entire problem definition present ...
      XPRSsetintcontrol(prob, XPRS_MIPDUALREDUCTIONS, 0)
      # ... add a callback for filtering invalid solutions.
      XPRSaddcbpreintsol(prob, cbPreIntSol, 0)
    end
  
    XPRSwriteprob(prob, "tsp.lp", "l")
  
    # Create a feasible starting tour.
    CreateInitialTour(prob)
  
    # Solve the TSP!
    XPRSoptimize(prob, "")
  
    # Check if we managed to solve our problem.
    mipstatus = XPRSgetintattrib(prob, XPRS_MIPSTATUS)
    if mipstatus == XPRS_MIP_OPTIMAL
      println("Optimal tour found:")
      PrintSolution(XPRSgetmipsol(prob, XPRS_ALLOC, nothing)[1])
    elseif mipstatus == XPRS_MIP_SOLUTION
      println("Solve was interrupted. Best tour found:")
      PrintSolution(XPRSgetmipsol(prob, XPRS_ALLOC, nothing)[1])
    elseif mipstatus == XPRS_MIP_INFEAS
      println("Problem unexpectedly found to be infeasible.")
    elseif mipstatus == XPRS_MIP_LP_NOT_OPTIMAL || mipstatus == XPRS_MIP_NO_SOL_FOUND
      println("Solve was interrupted without a solution found.")
    else
      println("Unexpected solution status $(mipstatus).")
    end
  
    # Check that list solution found is optimal
    @test XPRSgetintattrib(prob, XPRS_MIPSTATUS) == XPRS_MIP_OPTIMAL
  end

end

