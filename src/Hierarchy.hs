module Hierarchy where

import Data.List
import Data.Function
import Data.IntMap


topics :: IntMap (String, [Int])
topics = fromList [(0, ("CS", [])),
                   (1, ("PLT", [0])),
                   (2, ("programming", [])),
                   (3, ("languages", [1,2])),
                   (4, ("functional", [2,3])),
                   (5, ("imperative", [2,3])),
                   (6, ("pure", [4])),
                   (7, ("total", [4])),
                   (8, ("haskell", [6])),
                   (9, ("agda", [6,7])),
                   (10, ("scheme", [4,5])),
                   (11, ("c", [5])),
                   (12, ("type theory", [0])),
                   (13, ("books", [])),
                   (14, ("movies", [])),
                   (15, ("music", [])),
                   (16, ("idris", [6,7])),
                   (17, ("dev", []))
                  ]

restrictions :: IntMap (String, [Int])
restrictions = fromList [(0, ("general impoliteness", [])),
                         (1, ("swearing", [0])),
                         (2, ("politics", [0])),
                         (3, ("religion", [0])),
                         (4, ("personal life", [0])),
                         (5, ("health", [4])),
                         (6, ("money", [0])),
                         (7, ("etc", []))
                        ]

