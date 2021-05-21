# Getting started with SSProve

This document shall serve as a non-exhaustive guide to **SSProve**.

*This document assumes that you have Coq and SSProve installed and have already
some knowledge of Coq.*

🚧 **This document is very much work in progress** 🚧

## Overview

1. [Writing packages]
   1. [Raw code]
   1. [Specialised types]
   1. [Distributions]
   1. [Valid code]
   1. [Packages]
1. [High-level SSP proofs]
   1. [Package algebra]
   1. [Adversarial advantage]
1. [Probabilistic relational program logic]
   1. [Proving perfect indistinguishability]

## Writing packages

SSProve defines a language of *code* which can feature probabilistic sampling,
assertions, memory storing and accesses, but also external procedure import.
It is a *shallow embedding* meaning that one can inject any Coq/Gallina
expression into it by using the `ret` (standing for `return`) operation which we
will expose below.

### Raw code

The main notion of code is defined as the type `raw_code A` which represents
a program returning a value of type `A`. This type `A` is typically—but not
limited to—of type `chUniverse`.


Before detailing how to construct them, here is a first example with no
particular meaning.

```coq
#import {sig #[0] : 'nat → 'bool × 'nat } as f ;;
#import {sig #[1] : 'bool → 'unit } as g ;;
'(b,k) ← f 0 ;;
if b then (
  g false ;;
  m ← sample uniform 2 ;;
  ret 0
)
else (
  o ← get ℓ ;;
  #assert (isSome o) as oSome ;;
  let n := getSome o oSome in
  put n := Some (2 + n) ;;
  ret n
)
```
where `ℓ` is defined as
```coq
Definition ℓ : Location := ('option 'nat ; 0).
```

It first imports two procedures with respective identifiers `0` and `1` and
types `'nat → 'bool × 'bool` and `'bool → 'unit`, calling them `f` and `g`.
We take the result of `f` (the external procedure) applied to `0` as a pair
`(b,k)` and then do a case-analysis on `b`.
In the `else` branch, we read memory location `ℓ`, assert that it contains a
`Some`, reusing this fact (called `oSome`) to get the value itself.
We then increment this value twice and place it back in memory before
returning the original value.

#### Return constructor `ret`
```coq
ret : ∀ {A}, A → raw_code A
```
Injects any pure value into `raw_code`.

#### Memory access

A `Location` is a pair of a type in `chUniverse` and a natural number
representing an identifier, for instance `('nat ; 12) : Location`.
One can *read* memory as follows:
```coq
x ← get ℓ ;; k x
(* Or with pattern matching *)
'p ← get ℓ ;; k p
```
where `k` is a continuation, *i.e.* raw code which can depend on `x`.
One can *write* to a memory location as follows:
```coq
put ℓ := v ;; k
```
where `v` is a value of the right type and `k` a continuation, which this time
doesn't expect any value from the writing.

#### Probabilistic sampling
```coq
x ← sample op ;; k x
(* Or alternatively *)
x <$ op ;; k x
(* Or with pattern matching *)
'p ← sample op ;; k p
```
Here `op : Op` is a (sub-)distribution. See [Distributions].

#### Failure
```coq
fail : ∀ {A : chUniverse}, raw_code A
```
Represents a failure in a program. It is obtained by sampling on the null
sub-distribution.

#### Assertion
```coq
#assert b as e ;; k e
(* Alternatively, if the continuation doesn't need the equality *)
#assert b ;; k
```
Assert that the boolean `b` is `true` and store an equality `e : b = true`
to be reused by the continuation.
`#assert true as e ;; k e` simplifies to `k erefl` while
`#assert false as e ;; k e` simplifies to `fail`.

#### Import
```coq
x ← op sig ⋅ arg ;; k x
```
Represents application of imported/assumed procedure of signature `sig : opsig`
to argument `arg`, calling the result `x` before passing it to continuation `k`.
See [Specialised types] for how to define `sig`.
A preferred alternative to writing imports it to use the following notation
```coq
#import sig as f ;; k' f
```
where `f` bound in the continuation is a function which can be applied via bind.
For instance if `sig` is `{sig #[n] : 'nat → 'bool × 'bool }` then
`f` has type `nat → raw_code (bool * bool)` and can be used as
```
x ← f arg ;; k x
```

#### Bind
`raw_code` is a monad and as such it supports a *bind* operator. With value
reuse it can be written as follows:
```coq
x ← v ;; k x
(* Or with pattern matching *)
'p ← v ;; k p
```
and without, as
```coq
v ;; k
```
This operation is not a primitive/constructor and will reduce to the above
constructions when `v` is concrete.

### Specialised types

We have a special type called `chUniverse` which contains *codes* for specific
types that we use in our packages. These are the types used in `Location`
and in `opsig` or even in `Op`.

To differentiate them from actual types while retaining some familiarity
we usually style them with a quotation mark in front of the type they represent.
This is the case for instance of `'nat`, `'bool`, `'unit` and `'option` which
are self-explanatory.

We also provide `'fin n` which is the *inhabited* finite type of size `n`.
Under the hood, Coq will attempt to prove that `n` is non-zero.
In case it fails, the user should provide instances or hints for the
`Positive` type-class.

We also have the product type `chProd x y` which is interpreted to Coq's
product `prod`. For instance `chProd 'nat 'bool` corresponds to `nat * bool`.

Finally we have the type of finite maps `chMap x y` where `x` is the type of
keys, and `y` the type of values.

#### Further notation in specific settings

When defining signatures (`opsig`), interfaces (see [Valid code]), or packages
(see [Packages]), one can further use handy notations for `chProd` and
`chMap`, as exemplified below:

```coq
'nat × 'bool
{map 'nat → 'option 'nat }
```

#### Signatures

A signature (`opsig`) is given by an identifier (a natural number), an
argument type and a return type (both in `chUniverse`).
Once can for instance write `(37, ('nat, chProd 'unit 'unit))`.

We provide the following nicer notation:
```coq
{sig #[37] : 'nat → 'unit × 'unit }
```

### Distributions

The user can sample using pretty much any distribution that can be expressed
in `mathcomp-analysis` provided that its support is in `chUniverse`.
Writing them by hand might not be very convenient.

For the time being we provide `uniform n` which represents a uniform
distribution landing in `'fin n`. As such `n` must be positive
(Coq will look for an instance of `Positive n`).

### Valid code

[Raw code] as described above is well-typed but does not have any guarantees
with respect to what it imports and which location it uses. We therefore
define a notion a validity with respect to an import interface and a set of
locations.

#### Set of locations

The set of locations is expected as an `{fset Location }` using the finite
sets of the [extructures] library. For our purposes, it is advisable to write
them directly as list which of locations which is then cast to an `fset` using
the `fset` operation, as below:
```coq
fset [:: ℓ₀ ; ℓ₁ ; ℓ₂ ]
```
This is the best way to leverage the automation that we introduced.
Nevertheless, in some cases it might be more convenient to use the union
(`:|:`) operator of [extructures].

#### Interfaces

An interface is a set of signatures (`opsig`) corresponding to the procedures
that a piece of code *can* import and use.
Rather than writing them as `fset` directly, we provide special convenient
notations, as well the type `Interface`.

Interfaces are wrapped in the `[interface]` container which behaves like lists.
They are of the form
```coq
[interface d₀ ; d₁ ; … ; dₙ ]
```
where the `dᵢ` are signatures, given using a special syntax:
```coq
val #[ id ] : src → tgt
```
where `id` is a natural number / identifier, and `src` and `tgt` are codes of
types in `chUniverse` given using the special syntax (see [Specialised types]).

Here are examples of interfaces:
```coq
[interface]
```

```coq
[interface
  val #[ 0 ] : 'nat → 'nat ;
  val #[ 1 ] : 'option 'bool → 'unit × {map 'nat → 'bool }
]
```

#### Validity of code

Validity of code `c` with respect to set of locations `L` and import interface
`I` is denoted by the class `ValidCode L I c`.
We derive from it the type `code L I A` of valid code.

Raw code `c` can be cast to `code` by using the notation
```coq
{code c }
```

For instance, in the following, we declare a simple `code` by just giving
the `raw_code` and using the `{code}` notation:
```coq
Definition foo : code fset0 [interface] bool :=
  {code ret true }.
```

The fact that this is a class means that in practice, the validity proof
should automatically be inferred by Coq.
In case where automation doesn't work, it is still possible to leverage it to
find which sub-goal it did not solve for you by using the `ssprove_valid`
tactic.

Here is an example using `Equations` that allows us to use the proof mode to
fill in the validity proof.
```coq
Obligation Tactic := idtac.

Definition ℓ : Location := ('nat ; 0).

Equations? foo : code fset0 [interface] 'nat :=
  foo := {code
    n ← get ℓ ;;
    ret n
  }.
Proof.
  ssprove_valid.
  (* We have to prove ℓ \in fset0 which does not hold. *)
Abort.
```
We can then see where the mistake was and change the empty interface to
something containing `ℓ` like `fset [:: ℓ ]`.

Note that `ssprove_valid` and the inference for `ValidCode` can be extended
with hints. The former using the `packages` database, the latter with the
`typeclass_instances` database.

**Note:** There is an implicit coercion from `code` to `raw_code`.

### Packages

#### Package construction

We have a notion of `raw_package` which is a collection of procedures of the
form `src → raw_code tgt` distinguished by their signatures. This notion of
`raw_package` will prove the most efficient when proving results about packages,
such as advantages.
However, we provide a syntax to define valid packages by construction, *i.e.*
of type `package L I E` where each procedure must be `ValidCode L I tgt` and
the lot of them must implement export interface `E`.

The syntax for valid packages is similar to that of interfaces. Better explained
on an example:

```coq
Definition test :
  package
    fset0
    [interface
      val #[0] : 'nat → 'bool ;
      val #[1] : 'bool → 'unit
    ]
    [interface
      val #[2] : 'nat → 'nat ;
      val #[3] : 'bool × 'bool → 'bool
    ]
  :=
  [package
    def #[2] (n : 'nat) : 'nat {
      #import {sig #[0] : 'nat → 'bool } as f ;;
      #import {sig #[1] : 'bool → 'unit } as g ;;
      b ← f n ;;
      if b then
        g false ;;
        ret 0
      else ret n
    } ;
    def #[3] ('(b₀,b₁) : 'bool × 'bool) : 'bool {
      ret b₀
    }
  ].
```

Packages are wrapped in the `[package]` container which behaves like lists.
They are of the form
```coq
[package d₀ ; d₁ ; … ; dₙ ]
```
where the `dᵢ` are declarations, given using a special syntax:
```coq
def #[ id ] (x : src) : tgt { e }
```
where `id` is a natural number / identifier, and `src` and `tgt` are codes of
types in `chUniverse` given using the special syntax (see [Specialised types]),
while `e` is a regular Coq expression corresponding to the body of the function,
with `x` bound inside it.
As seen in the example, `x` can be matched against in the declaration by using
the `'p` notation where `p` is a pattern.

Similarly to `ValidCode`, there is an underlying `ValidPackage` class and we can
call its best effort version with `ssprove_valid`, for instance using
`Equations` (see [Valid code]).

In the example above we also explicitly gave an export interface while the
information is already present in the declaration. As such in can be omitted
as on the simpler example below:
```coq
Definition test' : package fset0 [interface] _ :=
  [package
    def #[ 0 ] (n : 'nat) : 'nat {
      ret (n + n)%N
    } ;
    def #[ 1 ] (b : 'bool) : 'nat {
      if b then ret 0 else ret 13
    }
  ].
```
The locations and import interface should however be given explicitly since
they are what the programs *can* use, not what they *exactly* use.

#### Composition of packages

One of the key points of SSP is its package algebra with sequential and parallel
composition as well as the identity package. All these operations are defined on
`raw_packages` directly but extend to `package` with the `{package}` and
`{locpackage}` notations.

Sequential composition is called `link` in SSProve and can be written
`p₀ ∘ p₁`. It represents `p₀` where all *imports* are replaced by the inlined
procedures of `p₁`. It is valid when the export interface of `p₁` matches the
import interface of `p₀`.

Parallel composition of (raw) packages `p₀` and `p₁` is written `par p₀ p₁`.
It is valid if we have `Parable p₀ p₁` (which is a class).
The resulting package must have the union of locations of its components, as
such automation can be lacking on that front, so it might be a good idea to rely
on `Equations` again:
```coq
Equations? pkg : package L I E :=
  pkg := {package (par p₀ p₁) ∘ p₂ }.
Proof.
  ssprove_valid.
  (* Now deal with the goals *)
```

Finally the identity package is defined as `ID I` where `I` is an interface.
It both imports and exports `I` by simply forwarding the calls.
It is valid as long as `I` does not include two signatures sharing the same
identifier, as overloading is not possible in our packages. This property is
written `flat I` and can be inferred automatically by `ssprove_ valid`.

As illustrated above, `{package p }` casts a raw package to some
`package L I E`, trying to infer the proof. We also have `{locpackage p }`
which will cast to `loc_package I E` which is essentially the same as `package`
but where the set of locations is internalised.

**Note:** `loc_package` and `package` both have implicit coercions to
`raw_package`. This means that, for instance, if `p₀` and `p₁` are both
`package` then, `{package p₀ ∘ p₁ }` is a valid expression, and will be complete
if the interfaces match.

## High-level SSP proofs

To reason at the high-level of state-separating proofs, we have two main
options.
The first one is the package algebra which involves laws on sequential and
parallel composition as well as on the identity package.
The second is when talking about advantage and corresponds mainly to the
triangle inequality and the reduction lemma.

Most of those apply to `raw_package` directly, but some will still have
some extra conditions which might be validity of some bits.

### Package algebra

The algebraic laws on packages are expressed as equalities (using Coq's equality
type `=`) on `raw_package`.

#### Associativity of sequential composition / linking

```coq
Lemma link_assoc :
  ∀ p₁ p₂ p₃,
    p₁ ∘ (p₂ ∘ p₃) = (p₁ ∘ p₂) ∘ p₃.
```

#### Commutativity of parallel composition

```coq
Lemma par_commut :
  ∀ p1 p2,
    Parable p1 p2 →
    par p1 p2 = par p2 p1.
```

#### Associativity of parallel composition

```coq
Lemma par_assoc :
  ∀ p1 p2 p3,
    par p1 (par p2 p3) = par (par p1 p2) p3.
```

#### Identity law

```coq
Lemma link_id :
  ∀ L I E p,
    ValidPackage L I E p →
    flat I →
    trimmed E p →
    link p (ID I) = p.
```

```coq
Lemma id_link :
  ∀ L I E p,
    ValidPackage L I E p →
    trimmed E p →
    link (ID E) p = p.
```

These laws require the package `p` to be valid but also to be `trimmed` which
means that it doesn't implement more than it exports. For packages constructed
as in [[Packages]], this is always the case.

#### Interchange between sequential and parallel composition

```coq
Lemma interchange :
  ∀ A B C D E F L₁ L₂ L₃ L₄ p₁ p₂ p₃ p₄,
    ValidPackage L₁ B A p₁ →
    ValidPackage L₂ E D p₂ →
    ValidPackage L₃ C B p₃ →
    ValidPackage L₄ F E p₄ →
    trimmed A p₁ →
    trimmed D p₂ →
    Parable p₃ p₄ →
    par (p₁ ∘ p₃) (p₂ ∘ p₄) = (par p₁ p₂) ∘ (par p₃ p₄).
```
The last line can be read as
```
(p₁ ∘ p₃) || (p₂ ∘ p₄) = (p₁ || p₂) ∘ (p₃ || p₄)
```

### Adversarial advantage

Security theorems in SSP will often conclude on an inequality of advantages.
We offer several ways to reason about them, but first we will show how to even
state such theorems.

#### Advantage and games

The simplest notion of advantage we have is `AdvantageE` of the following type
```coq
AdvantageE (G₀ G₁ A : raw_package) : R
```
`G₀` and `G₁` are the packages compared by the distinguisher/adversary `A`.
The result is a real number, of type `R`.

We also have an alternative version simply style `Advantage` which takes in a
`GamePair`:
```coq
Definition GamePair :=
  bool → raw_package.
```

```coq
Advantage (G : GamePair) (A : raw_package) : R
```

The two definitions are equivalent, as stated by the following. `AdvantageE`
should be preferred as it is slightly less constrained.
```coq
Lemma Advantage_E :
  ∀ (G : GamePair) A,
    Advantage G A = AdvantageE (G false) (G true) A.
```

We have several useful lemmata on advantage. We will list the important ones
below.

```coq
Lemma Advantage_link :
  ∀ G₀ G₁ A P,
    AdvantageE G₀ G₁ (A ∘ P) =
    AdvantageE (P ∘ G₀) (P ∘ G₁) A.
```
This one corresponds to the **reduction lemma** and is very useful.

```coq
Lemma Advantage_sym :
  ∀ P Q A,
    AdvantageE P Q A = AdvantageE Q P A.
```

```coq
Lemma Advantage_triangle :
  ∀ P Q R A,
    AdvantageE P Q A <= AdvantageE P R A + AdvantageE R Q A.
```
The **triangle inequality** is also very useful when reasoning about advantage.
As such we provide the user with an n-ary version of it which allows the user
to simulate game-hopping, in the form of a convenient tactic.

```coq
ssprove triangle p₀ [:: p₁ ; p₂ ; p₃ ] p₄ A as ineq.
```
will produce an inequality
```coq
ineq :
  AdvantageE p₀ p₄ A <= AdvantageE p₀ p₁ A +
                        AdvantageE p₁ p₂ A +
                        AdvantageE p₂ p₃ A +
                        AdvantageE p₃ p₄ A
```

#### Perfect indistinguishability

When the advantage of an adversary `A` (with disjoint state) against a game pair
`(G₀, G₁)` is `0`, we say that `G₀` and `G₁` are perfectly indistinguishable
and we write `G₀ ≈₀ G₁`.
Because this definition needs to talk about state, it can only apply to valid
packages. This notation indeed implicitly asks for the following:
```coq
ValidPackage L₀ Game_import E G₀
ValidPackage L₁ Game_import E G₁
```
for some `L₀`, `L₁` and `E`.
It is equivalent to the following:

```coq
∀ LA A,
  ValidPackage LA E A_export A →
  fdisjoint LA L₀ →
  fdisjoint LA L₁ →
  AdvantageE G₀ G₁ A = 0.
```
So one can use `G₀ ≈₀ G₁` to rewrite an advantage to `0`, typically after using
the triangle inequality, to eliminate some terms.
*Herein `A_export` is the export interface of an adversary, it contains a single
procedure `RUN` of type `'unit → 'bool`.*


## Probabilistic relational program logic

To prove perfect indistinguishability of two packages, we propose a low-level
probabilistic relational Hoare logic. We first show how to prove a statement
of the form `P ≈₀ Q` and then how to reason in this program logic.

### Proving perfect indistinguishability

The lemma of interest here is the following:
```coq
Lemma eq_rel_perf_ind :
  ∀ {L₀ L₁ E} (p₀ p₁ : raw_package) (inv : precond)
    `{ValidPackage L₀ Game_import E p₀}
    `{ValidPackage L₁ Game_import E p₁},
    Invariant L₀ L₁ inv →
    eq_up_to_inv E inv p₀ p₁ →
    p₀ ≈₀ p₁.
```
Most conditions are for `p₀ ≈₀ p₁` to even make sense. The important part is
that to prove `p₀ ≈₀ p₁` it suffices to prove that their procedures are related
in our program logic, while preserving an invariant `inv`.
An invariant relates the two heaps (state) used by `p₀` and `p₁` respectively.
The simplest example of invariant simply state equality of the two:
```coq
λ '(s₀, s₁), s₀ = s₁
```
To use it, one case use the following special case.
```coq
Corollary eq_rel_perf_ind_eq :
  ∀ {L₀ L₁ E} (p₀ p₁ : raw_package)
    `{ValidPackage L₀ Game_import E p₀}
    `{ValidPackage L₁ Game_import E p₁},
    eq_up_to_inv E (λ '(h₀, h₁), h₀ = h₁) p₀ p₁ →
    p₀ ≈₀ p₁.
```
We will say more about invariants later.

Once this lemma is applied, we need to simplify the `eq_up_to_inv` expression.
We have a set of tactics that help us achieve that automatically.

```coq
eapply eq_rel_perf_ind_eq.
simplify_eq_rel x. (* x is a name *)
all: ssprove_code_simpl.
```

`simplify_eq_rel x` will turn `eq_upto_inv` into one goal for each procedure,
`x` being the name for the argument in each case.
The goals it returns can be quite massive, with typically linking that is not
reduced (not inlined).
For each sub-goal (hence the goal selector `all:`), we apply the
`ssprove_code_simpl` tactic which we will describe in the next section.

### 🚧 **TODO** 🚧

🚧 **TODO** 🚧



[Writing packages]: #writing-packages
[Raw code]: #raw-code
[Specialised types]: #specialised-types
[Distributions]: #distributions
[Valid code]: #valid-code
[Packages]: #packages
[High-level SSP proofs]: #high-level-ssp-proofs
[Package algebra]: #package-algebra
[Adversarial advantage]: #adversarial-advantage
[Probabilistic relational program logic]: #probabilistic-relational-program-logic
[Proving perfect indistinguishability]: #proving-perfect-indistinguishability

[extructures]: https://github.com/arthuraa/extructures