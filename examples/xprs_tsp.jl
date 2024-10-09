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
using Random
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
const NUM_CITIES = 30

"""Maximum magnitude of each coordinate.

The coordinates for the nodes in our TSP
are drawn at random from this range."""
const MAX_COORD = 100

"""How to handle subtour elimination constraints.

- `0`: normal rows
- `1`: delayed rows
- `2`: cuts
"""
const SUBTOUR_TYPES = 2


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
  @assert XPRSgetintattrib(prob, XPRS_MIPSTATUS) == XPRS_MIP_OPTIMAL
end
