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
  @assert solvestatus != XPRS_SOLVESTATUS_COMPLETED
  @assert (solstatus != XPRS_SOLSTATUS_OPTIMAL) || (solstatus != XPRS_SOLSTATUS_FEASIBLE)
end