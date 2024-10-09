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
import JSON

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
  @assert solvestatus == XPRS_SOLVESTATUS_COMPLETED
  @assert (solstatus == XPRS_SOLSTATUS_OPTIMAL) || (solstatus == XPRS_SOLSTATUS_FEASIBLE)
  ind = 0
  for p in P, m in M
	  solval = XPRSgetlpsolval(prob, ind, 0)
	  println("Transport" * p * "=>" * m * ": " * string(solval[1]))
	  ind = ind + 1
  end
end
