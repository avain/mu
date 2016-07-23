## experimental compiler to translate programs of a generic
## expression-oriented language 'lambda' into mu

scenario convert-lambda [
  run [
    local-scope
    1:address:array:character/raw <- lambda-to-mu [(add a (multiply b c))]
    2:array:character/raw <- copy *1:address:array:character/raw
  ]
  memory-should-contain [
    2:array:character <- [t1 <- multiply b c
result <- add a t1]
  ]
]

def lambda-to-mu in:address:array:character -> out:address:array:character [
  local-scope
  load-ingredients
  out <- copy 0
  tmp:address:cell <- parse in
  out <- to-mu tmp
]

# 'parse' will turn lambda expressions into trees made of cells
exclusive-container cell [
  atom:address:array:character
  pair:pair
]

# printed below as < first | rest >
container pair [
  first:address:cell
  rest:address:cell
]

def new-atom name:address:array:character -> result:address:cell [
  local-scope
  load-ingredients
  result <- new cell:type
  *result <- merge 0/tag:atom, name
]

def new-pair a:address:cell, b:address:cell -> result:address:cell [
  local-scope
  load-ingredients
  result <- new cell:type
  *result <- merge 1/tag:pair, a/first, b/rest
]

def is-atom? x:address:cell -> result:boolean [
  local-scope
  load-ingredients
  reply-unless x, 0/false
  _, result <- maybe-convert *x, atom:variant
]

def is-pair? x:address:cell -> result:boolean [
  local-scope
  load-ingredients
  reply-unless x, 0/false
  _, result <- maybe-convert *x, pair:variant
]

def set-first base:address:cell, new-first:address:cell -> base:address:cell [
  local-scope
  load-ingredients
  pair:pair, is-pair?:boolean <- maybe-convert *base, pair:variant
  reply-unless is-pair?
  pair <- put pair, first:offset, new-first
  *base <- merge 1/pair, pair
]

def set-rest base:address:cell, new-rest:address:cell -> base:address:cell [
  local-scope
  load-ingredients
  pair:pair, is-pair?:boolean <- maybe-convert *base, pair:variant
  reply-unless is-pair?
  pair <- put pair, rest:offset, new-rest
  *base <- merge 1/pair, pair
]

scenario atom-is-not-pair [
  local-scope
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  10:boolean/raw <- is-atom? x
  11:boolean/raw <- is-pair? x
  memory-should-contain [
    10 <- 1
    11 <- 0
  ]
]

scenario pair-is-not-atom [
  local-scope
  # construct (a . nil)
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  y:address:cell <- new-pair x, 0/nil
  10:boolean/raw <- is-atom? y
  11:boolean/raw <- is-pair? y
  memory-should-contain [
    10 <- 0
    11 <- 1
  ]
]

def first x:address:cell -> result:address:cell [
  local-scope
  load-ingredients
  pair:pair, pair?:boolean <- maybe-convert *x, pair:variant
  reply-unless pair?, 0/nil
  result <- get pair, first:offset
]

def rest x:address:cell -> result:address:cell [
  local-scope
  load-ingredients
  pair:pair, pair?:boolean <- maybe-convert *x, pair:variant
  reply-unless pair?, 0/nil
  result <- get pair, rest:offset
]

scenario cell-operations-on-atom [
  local-scope
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  10:address:cell/raw <- first x
  11:address:cell/raw <- rest x
  memory-should-contain [
    10 <- 0  # first is nil
    11 <- 0  # rest is nil
  ]
]

scenario cell-operations-on-pair [
  local-scope
  # construct (a . nil)
  s:address:array:character <- new [a]
  x:address:cell <- new-atom s
  y:address:cell <- new-pair x, 0/nil
  x2:address:cell <- first y
  10:boolean/raw <- equal x, x2
  11:address:cell/raw <- rest y
  memory-should-contain [
    10 <- 1  # first is correct
    11 <- 0  # rest is nil
  ]
]

def parse in:address:array:character -> out:address:cell [
  local-scope
  load-ingredients
  s:address:stream <- new-stream in
  out, s <- parse s
]

def parse in:address:stream -> out:address:cell, in:address:stream [
  local-scope
  load-ingredients
  c:character <- peek in
  pair?:boolean <- equal c, 40/open-paren
  {
    break-if pair?
    # atom
    b:address:buffer <- new-buffer 30
    {
      done?:boolean <- end-of-stream? in
      break-if done?
      # stop before close paren
      c:character <- peek in
      done? <- equal c, 41/close-paren
      break-if done?
      # stop at spaces after consuming them
      c <- read in
      done? <- equal c, 32/space
      break-if done?
      b <- append b, c
      loop
    }
    s:address:array:character <- buffer-to-array b
    out <- new-atom s
  }
  {
    break-unless pair?
    # pair
    read in  # skip the open-paren
    out <- new cell:type  # start out with nil
    # read in first element of pair
    {
      done?:boolean <- end-of-stream? in
      break-if done?
      c <- peek in
      close-paren?:boolean <- equal c, 41/close-paren
      break-if close-paren?
      first:address:cell, in <- parse in
      *out <- merge 1/pair, first, 0/nil
    }
    # read in any remaining elements
    curr:address:cell <- copy out
    {
      done?:boolean <- end-of-stream? in
      break-if done?
      c <- peek in
      close-paren?:boolean <- equal c, 41/close-paren
      break-if close-paren?
      first:address:cell, in <- parse in
      new-curr:address:cell <- new-pair first, 0/nil
      curr <- set-rest curr, new-curr
      curr <- rest curr
      loop
    }
  }
]

scenario parse-single-letter-atom [
  local-scope
  s:address:array:character <- new [a]
  x:address:cell <- parse s
  s2:address:array:character, 10:boolean/raw <- maybe-convert *x, atom:variant
  11:array:character/raw <- copy *s2
  memory-should-contain [
    10 <- 1  # parse result is an atom
    11:array:character <- [a]
  ]
]

scenario parse-atom [
  local-scope
  s:address:array:character <- new [abc]
  x:address:cell <- parse s
  s2:address:array:character, 10:boolean/raw <- maybe-convert *x, atom:variant
  11:array:character/raw <- copy *s2
  memory-should-contain [
    10 <- 1  # parse result is an atom
    11:array:character <- [abc]
  ]
]

scenario parse-list-of-two-atoms [
  local-scope
  s:address:array:character <- new [(abc def)]
  x:address:cell <- parse s
  10:boolean/raw <- is-pair? x
  x1:address:cell <- first x
  x2:address:cell <- rest x
  s1:address:array:character, 11:boolean/raw <- maybe-convert *x1, atom:variant
  12:boolean/raw <- is-pair? x2
  x3:address:cell <- first x2
  s2:address:array:character, 13:boolean/raw <- maybe-convert *x3, atom:variant
  14:address:cell/raw <- rest x2
  20:array:character/raw <- copy *s1
  30:array:character/raw <- copy *s2
  memory-should-contain [
    # parses to < abc | < def | 0 > >
    10 <- 1  # parse result is a pair
    11 <- 1  # result.first is an atom
    12 <- 1  # result.rest is a pair
    13 <- 1  # result.rest.first is an atom
    14 <- 0  # result.rest.rest is nil
    20:array:character <- [abc]  # result.first
    30:array:character <- [def]  # result.rest.first
  ]
]

scenario parse-list-of-more-than-two-atoms [
  local-scope
  s:address:array:character <- new [(abc def ghi)]
  x:address:cell <- parse s
  10:boolean/raw <- is-pair? x
  x1:address:cell <- first x
  x2:address:cell <- rest x
  s1:address:array:character, 11:boolean/raw <- maybe-convert *x1, atom:variant
  12:boolean/raw <- is-pair? x2
  x3:address:cell <- first x2
  s2:address:array:character, 13:boolean/raw <- maybe-convert *x3, atom:variant
  x4:address:cell <- rest x2
  14:boolean/raw <- is-pair? x4
  x5:address:cell <- first x4
  s3:address:array:character, 15:boolean/raw <- maybe-convert *x5, atom:variant
  16:address:cell/raw <- rest x4
  20:array:character/raw <- copy *s1
  30:array:character/raw <- copy *s2
  40:array:character/raw <- copy *s3
  memory-should-contain [
    # parses to < abc | < def | < ghi | 0 > > >
    10 <- 1  # parse result is a pair
    11 <- 1  # result.first is an atom
    12 <- 1  # result.rest is a pair
    13 <- 1  # result.rest.first is an atom
    14 <- 1  # result.rest.rest is a pair
    15 <- 1  # result.rest.rest.first is an atom
    16 <- 0  # result.rest.rest.rest is nil
    20:array:character <- [abc]  # result.first
    30:array:character <- [def]  # result.rest.first
    40:array:character <- [ghi]  # result.rest.rest
  ]
]