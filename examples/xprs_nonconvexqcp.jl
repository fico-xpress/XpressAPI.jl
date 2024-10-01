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
  @assert solvestatus == XPRS_SOLVESTATUS_COMPLETED
  @assert (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)
end
