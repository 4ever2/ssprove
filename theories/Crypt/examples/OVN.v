
From Relational Require Import OrderEnrichedCategory GenericRulesSimple.

Set Warnings "-notation-overridden,-ambiguous-paths".
From mathcomp Require Import all_ssreflect all_algebra reals distr realsum
  fingroup.fingroup solvable.cyclic prime ssrnat ssreflect ssrfun ssrbool ssrnum
  eqtype choice seq.
Set Warnings "notation-overridden,ambiguous-paths".

From Crypt Require Import Axioms ChoiceAsOrd SubDistr Couplings
  UniformDistrLemmas FreeProbProg Theta_dens RulesStateProb UniformStateProb
  pkg_composition Package Prelude SigmaProtocol Schnorr DDH.

From Coq Require Import Utf8 Lia.
From extructures Require Import ord fset fmap.

From Equations Require Import Equations.
Require Equations.Prop.DepElim.

Set Equations With UIP.

Set Bullet Behavior "Strict Subproofs".
Set Default Goal Selector "!".
Set Primitive Projections.

Import Num.Def.
Import Num.Theory.
Import Order.POrderTheory.

#[local] Open Scope ring_scope.
Import GroupScope GRing.Theory.

Import PackageNotation.

Module Type GroupParam.

  Parameter n : nat.
  Parameter n_pos : Positive n.

  Parameter gT : finGroupType.
  Definition ζ : {set gT} := [set : gT].
  Parameter g :  gT.
  Parameter g_gen : ζ = <[g]>.
  Parameter prime_order : prime #[g].

End GroupParam.

Module Type OVNParam.

  Parameter N : nat.
  Parameter N_pos : Positive N.

End OVNParam.

Module OVN (GP : GroupParam) (OP : OVNParam).
Import GP.
Import OP.

Set Equations Transparent.

Lemma cyclic_zeta: cyclic ζ.
Proof.
  apply /cyclicP. exists g. exact: g_gen.
Qed.

(* order of g *)
Definition q' := Zp_trunc (pdiv #[g]).
Definition q : nat := q'.+2.

Lemma q_order_g : q = #[g].
Proof.
  unfold q, q'.
  apply Fp_cast.
  apply prime_order.
Qed.

Lemma group_prodC :
  @commutative gT gT mulg.
Proof.
  move => x y.
  have Hx: exists ix, x = g^+ix.
  { apply /cycleP. rewrite -g_gen.
    apply: in_setT. }
  have Hy: exists iy, y = g^+iy.
  { apply /cycleP. rewrite -g_gen.
    apply: in_setT. }
  destruct Hx as [ix Hx].
  destruct Hy as [iy Hy].
  subst.
  repeat rewrite -expgD addnC. reflexivity.
Qed.

Definition Pid : finType := [finType of 'I_n].
Definition Secret : finType := Zp_finComUnitRingType q'.
Definition Public : finType := FinGroup.arg_finType gT.
Definition s0 : Secret := 0.

Definition Pid_pos : Positive #|Pid|.
Proof.
  rewrite card_ord.
  eapply PositiveInFin.
  apply n_pos.
Qed.

Definition Secret_pos : Positive #|Secret|.
Proof.
  apply /card_gt0P. exists s0. auto.
Qed.

Definition Public_pos : Positive #|Public|.
Proof.
  apply /card_gt0P. exists g. auto.
Defined.

#[local] Existing Instance Pid_pos.
#[local] Existing Instance Secret_pos.
#[local] Existing Instance Public_pos.

Definition pid : chUniverse := 'fin #|Pid|.
Definition secret : chUniverse := 'fin #|Secret|.
Definition public: chUniverse := 'fin #|Public|.

Definition nat_to_pid : nat → pid.
Proof.
  move=> n.
  eapply give_fin.
Defined.

Definition i_secret := #|Secret|.
Definition i_public := #|Public|.

Module Type CDSParams <: SigmaProtocolParams.
  Definition Witness : finType := Secret.
  Definition Statement : finType := (prod_finType (prod_finType Public Public) Public).

  Definition Witness_pos : Positive #|Witness| := Secret_pos.
  Definition Statement_pos : Positive #|Statement|.
  Proof.
    unfold Statement.
    rewrite !card_prod.
    repeat apply Positive_prod.
    all: apply Public_pos.
  Qed.

  Definition R : Statement -> Witness -> bool :=
    λ (h : Statement) (x : Witness),
      let '(gx, gy, gyv) := h in
      (gx * g ^+ invg x == gyv ^+ invg x * invg gy * invg (g ^+ 0)) ||
      (gx == gyv * invg gy * invg (g ^+ 1)).

  Lemma relation_valid_left:
    ∀ (x : Secret) (gy : Public),
      R (g^+x, gy, gy^+x * g^+ 0) x.
  Proof.
    intros x gy.
    unfold R.
    rewrite expg0.
    rewrite mulg1.
    apply /orP ; left.
    rewrite invg1 mulg1.
    have Hgy: exists y, gy = g^+y.
    { apply /cycleP. rewrite -g_gen. apply: in_setT. }
    destruct Hgy as [y Hgy]. subst.
    simpl.
  Admitted.

  Lemma relation_valid_right:
    ∀ (x : Secret) (gy : Public),
      R (g^+x, gy, gy^+x * g^+ 1) x.
  Proof.
    intros x y.
    unfold R.
    rewrite expg0.
    rewrite invg1.
    rewrite mulg1.
    apply /orP ; right.
  Admitted.


  Parameter Message Challenge Response State : finType.
  Parameter w0 : Witness.
  Parameter e0 : Challenge.
  Parameter z0 : Response.

  Parameter Message_pos : Positive #|Message|.
  Parameter Challenge_pos : Positive #|Challenge|.
  Parameter Response_pos : Positive #|Response|.
  Parameter State_pos : Positive #|State|.
  Parameter Bool_pos : Positive #|bool_choiceType|.
End CDSParams.

Module OVN (π2 : CDSParams) (Alg2 : SigmaProtocolAlgorithms π2).

  Module Sigma1 := (Schnorr GP).
  Module Sigma2 := (SigmaProtocol π2 Alg2).

  Obligation Tactic := idtac.
  Set Equations Transparent.

  Definition secret_keys_loc : Location := (chMap pid secret; 0%N).
  Definition secret_locs : {fset Location} := fset [:: secret_keys_loc].

  Definition public_keys_loc : Location := (chMap pid (chProd public Sigma1.MyAlg.choiceTranscript) ; 2%N).
  Definition votes_loc : Location := (chMap pid (chProd public Alg2.choiceTranscript) ; 3%N).
  Definition public_locs : {fset Location} := fset [:: public_keys_loc ; votes_loc ].

  Definition skey_loc (i : nat) : Location := (secret; (100+i)%N).
  Definition ckey_loc (i : nat) : Location := (public; (101+i)%N).

  Definition P_i_locs (i : nat) : {fset Location} := fset [:: skey_loc i ; ckey_loc i].

  Definition all_locs : {fset Location} := (secret_locs :|: public_locs).

  Notation choiceStatement1 := Sigma1.MyAlg.choiceStatement.
  Notation choiceWitness1 := Sigma1.MyAlg.choiceWitness.
  Notation choiceTranscript1 := Sigma1.MyAlg.choiceTranscript.

  Notation " 'pid " := pid (in custom pack_type at level 2).
  Notation " 'pids " := (chProd pid pid) (in custom pack_type at level 2).
  Notation " 'public " := public (in custom pack_type at level 2).
  Notation " 'public " := public (at level 2) : package_scope.
  Notation " 'votes " := (chMap pid (chProd public Alg2.choiceTranscript)) (in custom pack_type at level 2).

  Notation " 'chRelation1' " := (chProd choiceStatement1 choiceWitness1) (in custom pack_type at level 2).
  Notation " 'chTranscript1' " := choiceTranscript1 (in custom pack_type at level 2).
  Notation " 'public_keys " := (chMap pid (chProd public choiceTranscript1)) (in custom pack_type at level 2).
  Notation " 'public_key " := (chProd public choiceTranscript1) (in custom pack_type at level 2).

  Notation " 'chRelation2' " := (chProd Alg2.choiceStatement Alg2.choiceWitness) (in custom pack_type at level 2).
  Notation " 'chTranscript2' " := Alg2.choiceTranscript (in custom pack_type at level 2).
  Notation " 'vote " := (chProd public Alg2.choiceTranscript) (in custom pack_type at level 2).

  Definition pack_statement2 (gx : Public) (gy : Public) (gyv : Public) : Alg2.choiceStatement.
  Proof.
    unfold Alg2.choiceStatement, π2.Statement, Public.
    apply fto ; repeat apply pair.
    - apply gx.
    - apply gy.
    - apply gyv.
  Defined.

  Definition pack_relation2 (gx : Public) (gy : Public) (gyv : Public) (x : Secret) : (chProd Alg2.choiceStatement Alg2.choiceWitness) :=
    (pack_statement2 gx gy gyv, fto x).

  Definition INIT : nat := 4.
  Definition VOTE : nat := 5.
  Definition CONSTRUCT : nat := 6.

  Definition P (i : nat) : nat := 14 + i.
  Definition Exec (i : nat) : nat := 15 + i.

  #[local] Hint Extern 1 (is_true (_ \in all_locs)) =>
    unfold all_locs; rewrite - fset_cat; auto_in_fset : typeclass_instances ssprove_valid_db.

  Lemma not_in_fsetU :
    ∀ (l : Location) L0 L1,
      l \notin L0  →
      l \notin L1 →
      l \notin L0 :|: L1.
  Proof.
    intros l L0 L1 h1 h2.
    rewrite -fdisjoints1 fset1E.
    rewrite fdisjointUl.
    apply /andP ; split.
    + rewrite -fdisjoints1 fset1E in h1. apply h1.
    + rewrite -fdisjoints1 fset1E in h2. apply h2.
  Qed.

  #[local] Hint Extern 3 (is_true (?l \notin ?L0 :|: ?L1)) =>
    apply not_in_fsetU : typeclass_instances ssprove_valid_db ssprove_invariant.

  Definition prod_gT (xs : list gT) : gT :=
    foldr (λ a b, a * b) 1 xs.

  Lemma prod_gT_aux xs ys y:
    prod_gT (xs ++ y :: ys) = prod_gT (y :: xs ++ ys).
  Proof.
    induction xs.
    - done.
    - simpl.
      rewrite IHxs.
      simpl.
      rewrite group_prodC.
      rewrite -mulgA.
      f_equal.
      rewrite group_prodC.
      done.
  Qed.

  Lemma prod_gT_cat xs ys:
    prod_gT (xs ++ ys) = prod_gT xs * prod_gT ys.
  Proof.
    induction ys.
    - simpl.
      by rewrite cats0 mulg1.
    - simpl.
      have -> : prod_gT xs * (a * prod_gT ys) = prod_gT xs * prod_gT ys * a.
      { rewrite -mulgA. f_equal. by rewrite group_prodC. }
      rewrite -IHys.
      rewrite prod_gT_aux.
      simpl.
      rewrite group_prodC.
      done.
  Qed.

  Definition get_value (m : chMap pid (chProd public choiceTranscript1)) (i : pid) :=
    match m i with
    | Some (v, _) => otf v
    | _ => 1
    end.

  Definition map_prod (m : chMap pid (chProd public choiceTranscript1)) :=
    (* foldr (fun i b => *)
    (*          match m i with *)
    (*          | Some (v, _) => otf v * b *)
    (*          | _ => b *)
    (*          end *)
    (*       ) 1 (domm m). *)
    \prod_(i <- domm m) (get_value m i).

  Lemma helper
        (i : pid)
        (v : chProd public choiceTranscript1)
        (m : chMap pid (chProd public choiceTranscript1)):
    setm m i v = setm (remm m i) i v.
  Proof.
    simpl.
    apply eq_fmap.
    intro k.
    rewrite !setmE remmE.
    case (eq_op) ; done.
  Qed.

  Canonical finGroup_com_law := Monoid.ComLaw group_prodC.

  Lemma map_prod_setm
        (i : pid)
        (v : chProd public choiceTranscript1)
        (m : chMap pid (chProd public choiceTranscript1)):
    map_prod (setm m i v) = map_prod (remm m i) * (otf v.1).
  Proof.
    unfold map_prod.
    simpl.
    rewrite helper.
    rewrite domm_set.
    simpl.
    set X := domm _.
    rewrite big_fsetU1.
    2: {
      subst X.
      rewrite domm_rem.
      unfold not.
      apply /negPn.
      unfold not.
      rewrite in_fsetD => H.
      move: H => /andP H.
      destruct H as [H _].
      move: H => /negPn H.
      apply H.
      by rewrite in_fset1.
    }
    simpl.
    unfold get_value.
    rewrite !setmE.
    rewrite eq_refl.
    destruct v as [x ?].
    rewrite group_prodC.
    f_equal.
    rewrite !big_seq.
    subst X.
    rewrite domm_rem.
    erewrite eq_bigr.
    1: done.
    intros k k_in.
    rewrite -helper.
    simpl.
    rewrite setmE remmE.
    case (eq_op) eqn:eq.
    - move: eq => /eqP eq.
      rewrite eq in k_in.
      rewrite in_fsetD1 in k_in.
      move: k_in => /andP [contra].
      unfold negb in contra.
      rewrite eq_refl in contra.
      discriminate.
    - done.
  Qed.

  Lemma domm_set':
    ∀ (T : ordType) (S : Type) (m : {fmap T → S}) (k : T) (v : S), domm (T:=T) (S:=S) (setm (T:=T) m k v) = k |: domm (T:=T) (S:=S) (remm m k).
  Proof.
    intros T S m k v.
    apply/eq_fset => k';
    apply /(sameP dommP) /(iffP idP);
    rewrite setmE in_fsetU1.
    - case /orP=> [->|].
      + eauto.
      + move=> /dommP.
        rewrite remmE.
        intros [v' ?].
        case eq_op in H.
        ++ discriminate.
        ++ case eq_op; eauto.
    - rewrite mem_domm.
      rewrite remmE.
      intros H.
      apply /orP.
      case (k' == k) eqn:eq.
      + by left.
      + right.
        destruct H as [v' ->].
        done.
  Qed.

  Definition compute_key
             (m : chMap pid (chProd public choiceTranscript1))
             (i : pid)
    :=
    let low := \prod_(k <- domm m | (k < i)%ord) (get_value m k) in
    let high := \prod_(k <- domm m | (i < k)%ord) (get_value m k) in
    low * invg high.

  Definition get_value_no_zkp (m : chMap pid public) (i : pid) :=
    match m i with
    | Some v => otf v
    | _ => 1
    end.

  Definition compute_key_no_zkp
             (m : chMap pid public)
             (i : pid)
    :=
    let low := \prod_(k <- domm m | (k < i)%ord) (get_value_no_zkp m k) in
    let high := \prod_(k <- domm m | (i < k)%ord) (get_value_no_zkp m k) in
    low * invg high.

  Lemma compute_key_ignore_zkp
             (m : chMap pid (chProd public choiceTranscript1))
             (i j : pid)
             zk x:
    compute_key (setm m j (x, zk)) i = compute_key_no_zkp (setm (mapm fst m) j x) i.
  Proof.
    unfold compute_key, compute_key_no_zkp.
    simpl.
    rewrite !domm_set.
    rewrite domm_map.
    f_equal.
    - erewrite eq_bigr.
      1: done.
      intros k k_lt.
      unfold get_value, get_value_no_zkp.
      rewrite !setmE mapmE.
      case (eq_op).
      1: reflexivity.
      destruct (m k) eqn:eq_m.
      + rewrite eq_m.
        destruct s.
        done.
      + by rewrite eq_m.
    - f_equal.
      erewrite eq_bigr.
      1: done.
      intros k k_lt.
      unfold get_value, get_value_no_zkp.
      rewrite !setmE mapmE.
      case (eq_op).
      1: reflexivity.
      destruct (m k) eqn:eq_m.
      + rewrite eq_m.
        destruct s.
        done.
      + by rewrite eq_m.
  Qed.

  Definition compute_key'
             (m : chMap pid (chProd public choiceTranscript1))
             (i j : pid)
             (x : Secret)
    :=
    if (j < i)%ord then
      let low := \prod_(k <- domm m | (k < i)%ord) (get_value m k) in
      let high := \prod_(k <- domm m | (i < k)%ord) (get_value m k) in
      (g ^+ x) * low * invg high
    else
      let low := \prod_(k <- domm m | (k < i)%ord) (get_value m k) in
      let high := \prod_(k <- domm m | (i < k)%ord) (get_value m k) in
      low * invg (high * (g ^+ x)).

  Lemma filterm_step
        (i : pid)
        (keys : chMap pid (chProd public choiceTranscript1))
        (pred : pid → (chProd public choiceTranscript1) → bool)
    :
    filterm pred keys =
      match (keys i) with
      | Some e => if (pred i e) then setm (filterm (λ k v, (pred k v) && (k != i)) keys) i e
                               else (filterm (λ k v, (pred k v)) keys)
      | _ => (filterm (λ k v, (pred k v)) keys)
      end.
  Proof.
    simpl.
    case (keys i) eqn:eq ; rewrite eq.
    2: done.
    case (pred i s) eqn:eq_pred.
    2: done.
    rewrite -eq_fmap.
    intros k.
    case (k == i) eqn:eq_k.
    + rewrite filtermE.
      rewrite setmE.
      rewrite filtermE.
      rewrite eq_k.
      move: eq_k => /eqP eq_k.
      rewrite -eq_k in eq.
      rewrite -eq_k in eq_pred.
      rewrite eq.
      simpl.
      rewrite eq_pred.
      done.
    + rewrite filtermE.
      rewrite setmE.
      rewrite filtermE.
      rewrite eq_k.
      simpl.
      case (keys k) eqn:eq'.
      ++ rewrite eq'.
         simpl.
         rewrite Bool.andb_true_r.
         done.
      ++ rewrite eq'.
         done.
  Qed.

  Lemma compute_key'_equiv
        (i j : pid)
        (x : Secret)
        (zk : choiceTranscript1)
        (keys : chMap pid (chProd public choiceTranscript1)):
    (i != j) →
    compute_key (setm keys j (fto (g ^+ x), zk)) i = compute_key' (remm keys j) i j x.
  Proof.
    intro ij_neq.
    unfold compute_key, compute_key'.
    simpl.
    case (j < i)%ord eqn:e.
    - rewrite e.
      rewrite helper.
      simpl.
      rewrite domm_set domm_rem.
      set X := domm _.
      rewrite !big_fsetU1.
      2: {
        subst X.
        apply /negPn.
        rewrite in_fsetD => H.
        move: H => /andP H.
        destruct H as [H _].
        move: H => /negPn H.
        apply H.
        by rewrite in_fset1.
      }
      2: {
        subst X.
        apply /negPn.
        rewrite in_fsetD => H.
        move: H => /andP H.
        destruct H as [H _].
        move: H => /negPn H.
        apply H.
        by rewrite in_fset1.
      }
      rewrite -helper.
      rewrite e.
      simpl.
      rewrite -mulgA.
      rewrite -mulgA.
      f_equal.
      { unfold get_value. by rewrite setmE eq_refl otf_fto. }
      f_equal.
      + simpl.
        rewrite big_seq_cond.
        rewrite [RHS] big_seq_cond.
        unfold get_value.
        erewrite eq_bigr.
        1: done.
        intros k k_in.
        move: k_in => /andP [k_in k_lt].
        simpl.
        rewrite setmE remmE.
        case (k == j) eqn:eq.
        ++ move: eq => /eqP eq.
           rewrite eq in_fsetD1 in k_in.
           move: k_in => /andP [contra].
           rewrite eq_refl in contra.
           discriminate.
        ++ by rewrite eq.
    + rewrite Ord.ltNge in e.
      rewrite Ord.leq_eqVlt in e.
      rewrite negb_or in e.
      move: e => /andP e.
      destruct e as [_ e].
      rewrite -eqbF_neg in e.
      move: e => /eqP e.
      rewrite e.
      f_equal.
      rewrite big_seq_cond.
      rewrite [RHS] big_seq_cond.
      unfold get_value.
      erewrite eq_bigr.
      1: done.
      intros k k_in.
      move: k_in => /andP [k_in k_lt].
      simpl.
      rewrite setmE remmE.
      case (k == j) eqn:eq.
      ++ move: eq => /eqP eq.
          rewrite eq in_fsetD1 in k_in.
          move: k_in => /andP [contra].
          rewrite eq_refl in contra.
          discriminate.
      ++ by rewrite eq.
    - rewrite e.
      rewrite helper.
      simpl.
      rewrite domm_set domm_rem.
      set X := domm _.
      rewrite !big_fsetU1.
      2: {
        subst X.
        apply /negPn.
        rewrite in_fsetD => H.
        move: H => /andP H.
        destruct H as [H _].
        move: H => /negPn H.
        apply H.
        by rewrite in_fset1.
      }
      2: {
        subst X.
        apply /negPn.
        rewrite in_fsetD => H.
        move: H => /andP H.
        destruct H as [H _].
        move: H => /negPn H.
        apply H.
        by rewrite in_fset1.
      }
      rewrite -helper e.
      rewrite Ord.ltNge in e.
      apply negbT in e.
      apply negbNE in e.
      rewrite Ord.leq_eqVlt in e.
      move: e => /orP [contra|e].
      1: by rewrite contra in ij_neq.
      rewrite e.
      simpl.
      rewrite !invMg.
      f_equal.
      {
        rewrite big_seq_cond.
        rewrite [RHS] big_seq_cond.
        erewrite eq_bigr.
        1: done.
        intros k H.
        unfold get_value.
        rewrite remmE setmE.
        case (k == j) eqn:eq_k.
        + move: H => /andP [H _].
          rewrite in_fsetD1 in H.
          move: eq_k => /eqP eq_k.
          move: H => /andP [H _].
          rewrite eq_k in H.
          by rewrite eq_refl in H.
        + by rewrite eq_k.
      }
      rewrite group_prodC.
      f_equal.
      { unfold get_value. by rewrite setmE eq_refl otf_fto. }
      f_equal.
      rewrite big_seq_cond.
      rewrite [RHS] big_seq_cond.
      unfold get_value.
      erewrite eq_bigr.
      1: done.
      intros k k_in.
      move: k_in => /andP [k_in k_lt].
      simpl.
      rewrite setmE remmE.
      case (k == j) eqn:eq.
      ++ move: eq => /eqP eq.
          rewrite eq in_fsetD1 in k_in.
          move: k_in => /andP [contra].
          rewrite eq_refl in contra.
          discriminate.
      ++ by rewrite eq.
  Qed.

  Lemma compute_key_bij:
    ∀ (m : chMap pid (chProd public choiceTranscript1)) (i j: pid),
      (i != j)%ord →
      exists (a b : nat),
        (a != 0)%N /\ (a < q)%N /\
      (∀ (x : Secret) zk,
        compute_key (setm m j (fto (g ^+ x), zk)) i = g ^+ ((a * x + b) %% q)).
  Proof.
    simpl.
    intros m i j ne.
    pose low := \prod_(k <- domm m :\ j| (k < i)%ord) get_value m k.
    pose hi := \prod_(k <- domm m :\ j| (i < k)%ord) get_value m k.
    have Hlow : exists ilow, low = g ^+ ilow.
    { apply /cycleP. rewrite -g_gen.
      apply: in_setT. }
    have Hhi : exists ihi, hi = g ^+ ihi.
    { apply /cycleP. rewrite -g_gen.
      apply: in_setT. }
    destruct Hlow as [ilow Hlow].
    destruct Hhi as [ihi Hhi].
    case (j < i)%ord eqn:ij_rel.
    - exists 1%N.
      exists (ilow + (ihi * #[g ^+ ihi].-1))%N.
      do 2 split.
      1: rewrite q_order_g ; apply (prime_gt1 prime_order).
      intros x zk.
      rewrite compute_key'_equiv.
      2: assumption.
      unfold compute_key'.
      simpl.
      rewrite ij_rel.
      rewrite domm_rem.
      set low' := \prod_(k0 <- _ | _) _.
      set hi' := \prod_(k0 <- _ | _) _.
      have -> : low' = low.
      {
        unfold low, low'.
        rewrite big_seq_cond.
        rewrite [RHS] big_seq_cond.
        erewrite eq_bigr.
        1: done.
        intros k k_in.
        move: k_in => /andP [k_in k_lt].
        simpl.
        unfold get_value.
        rewrite remmE.
        case (k == j) eqn:eq.
        ++ move: eq => /eqP eq.
            rewrite eq in_fsetD1 in k_in.
            move: k_in => /andP [contra].
            rewrite eq_refl in contra.
            discriminate.
        ++ by rewrite eq.
      }
      have -> : hi' = hi.
      {
        unfold hi, hi'.
        rewrite big_seq_cond.
        rewrite [RHS] big_seq_cond.
        erewrite eq_bigr.
        1: done.
        intros k k_in.
        move: k_in => /andP [k_in k_lt].
        simpl.
        unfold get_value.
        rewrite remmE.
        case (k == j) eqn:eq.
        ++ move: eq => /eqP eq.
            rewrite eq in_fsetD1 in k_in.
            move: k_in => /andP [contra].
            rewrite eq_refl in contra.
            discriminate.
        ++ by rewrite eq.
      }
      clear low' hi'.
      rewrite Hhi Hlow.
      rewrite invg_expg.
      rewrite -!expgM.
      rewrite -!expgD.
      rewrite !addnA.
      rewrite -expg_mod_order.
      f_equal.
      f_equal.
      2: {
        unfold q. rewrite Fp_cast;
        [reflexivity | apply prime_order].
      }
      rewrite mul1n.
      done.
    - exists #[g].-1.
      exists (ilow + (ihi * #[g ^+ ihi].-1))%N.
      repeat split.
      { unfold negb.
        rewrite -leqn0.
        case (#[g].-1 <= 0)%N eqn:e.
        2: done.
        have Hgt1 := (prime_gt1 prime_order).
        rewrite -ltn_predRL in Hgt1.
        rewrite -ltnS in Hgt1.
        rewrite -addn1 in Hgt1.
        rewrite leq_add2l in Hgt1.
        eapply leq_trans in e.
        2: apply Hgt1.
        discriminate.
      }
      {
        rewrite q_order_g.
        rewrite ltn_predL.
        apply (prime_gt0 prime_order).
      }
      intros x zk.
      rewrite compute_key'_equiv.
      2: assumption.
      unfold compute_key'.
      simpl.
      rewrite ij_rel.
      rewrite domm_rem.
      set low' := \prod_(k0 <- _ | _) _.
      set hi' := \prod_(k0 <- _ | _) _.
      have -> : low' = low.
      {
        unfold low, low'.
        rewrite big_seq_cond.
        rewrite [RHS] big_seq_cond.
        erewrite eq_bigr.
        1: done.
        intros k k_in.
        move: k_in => /andP [k_in k_lt].
        simpl.
        unfold get_value.
        rewrite remmE.
        case (k == j) eqn:eq.
        ++ move: eq => /eqP eq.
            rewrite eq in_fsetD1 in k_in.
            move: k_in => /andP [contra].
            rewrite eq_refl in contra.
            discriminate.
        ++ by rewrite eq.
      }
      have -> : hi' = hi.
      {
        unfold hi, hi'.
        rewrite big_seq_cond.
        rewrite [RHS] big_seq_cond.
        erewrite eq_bigr.
        1: done.
        intros k k_in.
        move: k_in => /andP [k_in k_lt].
        simpl.
        unfold get_value.
        rewrite remmE.
        case (k == j) eqn:eq.
        ++ move: eq => /eqP eq.
            rewrite eq in_fsetD1 in k_in.
            move: k_in => /andP [contra].
            rewrite eq_refl in contra.
            discriminate.
        ++ by rewrite eq.
      }
      clear low' hi'.
      rewrite Hhi Hlow.
      rewrite invMg.
      rewrite -expgVn.
      rewrite !invg_expg.
      rewrite -!expgM.
      rewrite mulgA.
      rewrite -!expgD.
      rewrite !addnA.
      rewrite -expg_mod_order.
      f_equal.
      f_equal.
      2: {
        unfold q. rewrite Fp_cast;
        [reflexivity | apply prime_order].
      }
      rewrite addnAC.
      rewrite addnC.
      rewrite addnA.
      done.
  Qed.

  Lemma compute_key_set_i
        (i : pid)
        (v : (chProd public choiceTranscript1))
        (m : chMap pid (chProd public choiceTranscript1)):
    compute_key (setm m i v) i = compute_key m i.
  Proof.
    unfold compute_key.
    simpl.
    case (i \in domm m) eqn:i_in.
    all: simpl in i_in.
    - have -> : domm (setm m i v) = domm m.
      {
        simpl.
        rewrite domm_set.
        rewrite -eq_fset.
        intro k.
        rewrite in_fsetU1.
        case (eq_op) eqn:e.
        + move: e => /eqP ->.
          by rewrite i_in.
        + done.
      }
      simpl.
      f_equal.
      + apply eq_big.
        1: done.
        intros k k_lt.
        unfold get_value.
        rewrite setmE.
        rewrite Ord.lt_neqAle in k_lt.
        move: k_lt => /andP [k_lt _].
        move: k_lt => /negbTE ->.
        done.
      + f_equal.
        apply eq_big.
        1: done.
        intros k k_lt.
        unfold get_value.
        rewrite setmE.
        rewrite Ord.lt_neqAle in k_lt.
        move: k_lt => /andP [k_lt _].
        rewrite eq_sym.
        move: k_lt => /negbTE ->.
        done.
    - have -> : domm m = domm (remm m i).
      {
        simpl.
        rewrite -eq_fset.
        intro k.
        rewrite domm_rem.
        rewrite in_fsetD1.
        case (eq_op) eqn:e.
        + simpl.
          move: e => /eqP ->.
          assumption.
        + done.
      }
      simpl.
      f_equal.
      + rewrite helper domm_set domm_rem.
        rewrite big_fsetU1.
        all: simpl.
        2: by rewrite in_fsetD1 eq_refl.
        rewrite Ord.ltxx.
        apply eq_big.
        1: done.
        intros k k_lt.
        unfold get_value.
        rewrite setmE remmE.
        rewrite Ord.lt_neqAle in k_lt.
        move: k_lt => /andP [k_lt _].
        move: k_lt => /negbTE ->.
        done.
      + f_equal.
        rewrite helper domm_set domm_rem.
        rewrite big_fsetU1.
        all: simpl.
        2: by rewrite in_fsetD1 eq_refl.
        rewrite Ord.ltxx.
        apply eq_big.
        1: done.
        intros k k_lt.
        unfold get_value.
        rewrite setmE remmE.
        rewrite Ord.lt_neqAle in k_lt.
        move: k_lt => /andP [k_lt _].
        rewrite eq_sym.
        move: k_lt => /negbTE ->.
        done.
  Qed.

  Lemma test_bij
        (i j : pid)
        (m : chMap pid (chProd public choiceTranscript1))
    :
      (i != j)%N →
      ∃ (f : Secret → Secret),
      ∀ (x : Secret),
        bijective f /\
          (∀ zk, compute_key (setm m j (fto (g ^+ x), zk)) i = g ^+ (f x)).
  Proof.
    simpl.
    intros ne.
    have H := compute_key_bij m i j ne.
    simpl in H.
    destruct H as [a [b [a_pos [a_leq_q H]]]].
    set a_ord := @inZp (q'.+1) a.
    set b_ord := @inZp (q'.+1) b.
    pose f' := (fun (x : Secret) => Zp_add (Zp_mul x a_ord) b_ord).
    exists f'.
    unfold f'. clear f'.
    intros x.
    have := q_order_g.
    unfold q.
    intros Hq.
    split.
    2: {
      intro zk.
      rewrite (H x zk).
      apply /eqP.
      rewrite eq_expg_mod_order.
      apply /eqP.
      simpl.
      rewrite modn_small.
      2: {
        rewrite q_order_g.
        apply ltn_pmod.
        apply (prime_gt0 prime_order).
      }
      symmetry.
      rewrite modn_small.
      2: {
        repeat rewrite -> Hq at 2.
        apply ltn_pmod.
        apply (prime_gt0 prime_order).
      }
      simpl.
      repeat rewrite -> Hq at 2.
      unfold q.
      rewrite -> Hq at 3.
      rewrite modnMmr.
      rewrite modnDm.
      rewrite mulnC.
      reflexivity.
    }
    assert (coprime q'.+2 a_ord) as a_ord_coprime.
    {
      rewrite -unitFpE.
      2: rewrite Hq ; apply prime_order.
      rewrite unitfE. simpl.
      rewrite modn_small.
      2: apply a_leq_q.
      erewrite <- inj_eq.
      2: apply ord_inj.
      rewrite val_Zp_nat.
      2: {
        rewrite pdiv_id.
        1: apply prime_gt1.
        1,2: rewrite Hq ; apply prime_order.
      }
      rewrite -> pdiv_id at 1.
      1,2: rewrite Hq.
      2: apply prime_order.
      unfold q in a_leq_q.
      rewrite Hq in a_leq_q.
      rewrite modn_small.
      2: apply a_leq_q.
      assumption.
    }
    pose f' := (fun (x : Secret) => Zp_mul (Zp_add (Zp_opp b_ord) x) (Zp_inv a_ord)).
    exists f'.
    - intro z.
      unfold f'. clear f'.
      simpl.
      rewrite Zp_addC.
      rewrite -Zp_addA.
      have -> : (Zp_add b_ord (Zp_opp b_ord)) = Zp0.
      1: by rewrite Zp_addC Zp_addNz.
      rewrite Zp_addC.
      rewrite Zp_add0z.
      rewrite -Zp_mulA.
      rewrite Zp_mulzV.
      2: assumption.
      rewrite Zp_mulz1.
      reflexivity.
    - intro z.
      unfold f'. clear f'.
      simpl.
      rewrite Zp_addC.
      rewrite -Zp_mulA.
      rewrite Zp_mul_addl.
      have -> : (Zp_mul (Zp_inv a_ord) a_ord) = Zp1.
      {
        rewrite Zp_mulC.
        rewrite Zp_mulzV.
        + reflexivity.
        + assumption.
      }
      rewrite -Zp_mul_addl.
      rewrite Zp_mulz1.
      rewrite Zp_addA.
      have -> : (Zp_add b_ord (Zp_opp b_ord)) = Zp0.
      1: by rewrite Zp_addC Zp_addNz.
      rewrite Zp_add0z.
      reflexivity.
  Qed.

  Lemma test_bij'
        (i j : pid)
        (m : chMap pid (chProd public choiceTranscript1))
    :
      (i != j)%N →
      ∃ (f : secret → secret),
      ∀ (x : secret),
        bijective f /\
          (∀ zk, compute_key (setm m j (fto (g ^+ otf x), zk)) i = g ^+ (otf (f x))).
  Proof.
    simpl.
    intros ne.
    have [f H] := test_bij i j m ne.
    simpl in H.
    exists (fun (x : secret) => fto (f (otf x))).
    intro x.
    destruct (H (otf x)) as [f_bij H'] ; clear H.
    split.
    - exists (fun z => fto ((finv f) (otf z))).
      + apply bij_inj in f_bij.
        intro z.
        rewrite otf_fto.
        apply finv_f in f_bij.
        rewrite f_bij fto_otf.
        reflexivity.
      + apply bij_inj in f_bij.
        intro z.
        simpl.
        rewrite otf_fto.
        apply f_finv in f_bij.
        rewrite f_bij fto_otf.
        reflexivity.
    - intro zk.
      specialize (H' zk).
      rewrite otf_fto.
      apply H'.
  Qed.

  Definition P_i_E :=
    [interface
         val #[ INIT ] : 'unit → 'public_key ;
         val #[ CONSTRUCT ] : 'public_keys → 'unit ;
         val #[ VOTE ] : 'bool → 'public
    ].

  Definition Sigma1_I :=
    [interface
         val #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool ;
         val #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1
    ].

  Definition P_i (i : pid) (b : bool):
    package (P_i_locs i)
      Sigma1_I
      P_i_E :=
    [package
        def #[ INIT ] (_ : 'unit) : 'public_key
        {
          #import {sig #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1} as ZKP ;;
          #import {sig #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool} as VER ;;
          x ← sample uniform i_secret ;;
          put (skey_loc i) := x ;;
          let y := (fto (g ^+ (otf x))) : public in
            zkp ← ZKP (y, x) ;;
            ret (y, zkp)
        }
        ;
        def #[ CONSTRUCT ] (m : 'public_keys) : 'unit
        {
          #import {sig #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool} as VER ;;
          #assert (size (domm m) == n) ;;
          let key := fto (compute_key m i) in
          put (ckey_loc i) := key ;;
          @ret 'unit Datatypes.tt
        }
        ;
        def #[ VOTE ] (v : 'bool) : 'public
        {
          skey ← get (skey_loc i) ;;
          ckey ← get (ckey_loc i) ;;
          if b then
            let vote := (otf ckey ^+ skey * g ^+ v) in
            @ret 'public (fto vote)
          else
            let vote := (otf ckey ^+ skey * g ^+ (negb v)) in
            @ret 'public (fto vote)
        }
    ].

  Definition EXEC_i_I :=
    [interface
         val #[ INIT ] : 'unit → 'public_key ;
         val #[ CONSTRUCT ] : 'public_keys → 'unit ;
         val #[ VOTE ] : 'bool → 'public ;
         val #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1
    ].

  Definition Exec_i_E i := [interface val #[ Exec i ] : 'bool → 'public].

  Definition Exec_i (i j : pid) (m : chMap pid (chProd public choiceTranscript1)):
    package fset0
      EXEC_i_I
      (Exec_i_E i)
    :=
    [package
        def #[ Exec i ] (v : 'bool) : 'public
        {
          #import {sig #[ INIT ] : 'unit → 'public_key} as Init ;;
          #import {sig #[ CONSTRUCT ] : 'public_keys → 'unit} as Construct ;;
          #import {sig #[ VOTE ] : 'bool → 'public} as Vote ;;
          #import {sig #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1} as ZKP ;;
          pk ← Init Datatypes.tt ;;
          x ← sample uniform i_secret ;;
          let y := (fto (g ^+ (otf x))) : public in
            zkp ← ZKP (y, x) ;;
            let m' := setm (setm m j (y, zkp)) i pk in
              Construct m' ;;
              vote ← Vote v ;;
              @ret 'public vote
        }
    ].

  (* Definition Init (id : pid) : *)
  (*   code fset0 *)
  (*     [interface *)
  (*        val #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool ; *)
  (*        val #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1 *)
  (*     ] (chProd secret (chProd public choiceTranscript1)) := *)
  (*   {code *)
  (*     #import {sig #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1} as ZKP ;; *)
  (*     #import {sig #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool} as VER ;; *)
  (*     x ← sample uniform i_secret ;; *)
  (*     let y := (fto (g ^+ (otf x))) : public in *)
  (*       zkp ← ZKP (y, x) ;; *)
  (*       ret (x, (y, zkp)) *)
  (*   }. *)

  (* Definition Construct_key (i : pid) (m : chMap pid (chProd public choiceTranscript1)): *)
  (*   code fset0 *)
  (*     [interface *)
  (*        val #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool *)
  (*     ] 'public := *)
  (*   {code *)
  (*     #import {sig #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool} as VER ;; *)
  (*     #assert (size (domm m) == n) ;; *)
  (*     let key := compute_key m i in *)
  (*     @ret 'public (fto key) *)
  (*   }. *)

  (* Definition SETUP_I := *)
  (*     [interface *)
  (*        val #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool ; *)
  (*        val #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1 *)
  (*     ]. *)

  (* Definition SETUP_E := [interface val #[ INIT ] : 'unit → 'unit]. *)

  (* Notation " 'setup " := (chProd secret public) (in custom pack_type at level 2). *)

  (* Equations? SETUP_real (m : chMap pid (chProd public choiceTranscript1)) *)
  (*          (i j : pid) : *)
  (*   package public_locs *)
  (*     SETUP_I *)
  (*     SETUP_E := *)
  (*   SETUP_real m i j := *)
  (*   [package *)
  (*       def #[ INIT ] (_ : 'unit) : 'setup *)
  (*       { *)
  (*         r1 ← Init i ;; *)
  (*         r2 ← Init j ;; *)
  (*         let '(x1, zkp1) := r1 in *)
  (*         let '(x2, zkp2) := r2 in *)
  (*         let m' := (setm (setm m j zkp2) i zkp1) in *)
  (*         put public_keys_loc := m' ;; *)
  (*         ckey ← Construct_key i m' ;; *)
  (*         ret (x1, ckey) *)
  (*       } *)
  (*   ]. *)
  (* Proof. *)
  (*   ssprove_valid. *)
  (*   unfold ValidPackage. *)
  (*   eapply pack_valid. *)
  (*   all: eapply valid_injectMap. *)
  (*   2,4,6: eapply valid_injectLocations. *)
  (*   3,5: apply Init. *)
  (*   5: apply Construct_key. *)
  (*   all: try fsubset_auto. *)
  (*   all: apply fsubsetxx. *)
  (* Qed. *)

  (* Definition SETUP_ideal (m : chMap pid (chProd public choiceTranscript1)) *)
  (*            (i j : pid) *)
  (*            (f : secret → secret): *)
  (*   package all_locs *)
  (*     SETUP_I *)
  (*     SETUP_E := *)
  (*   [package *)
  (*       def #[ INIT ] (_ : 'unit) : 'unit *)
  (*       { *)
  (*       #import {sig #[ Sigma1.Sigma.VERIFY ] : chTranscript1 → 'bool} as VER ;; *)
  (*       #import {sig #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1} as ZKP ;; *)
  (*       zkp1 ← Init i ;; *)
  (*       x ← sample uniform i_secret ;; *)
  (*       secrets ← get secret_keys_loc ;; *)
  (*       put secret_keys_loc := setm secrets j x ;; *)
  (*       let y := (fto (g ^+ (otf ((finv f) x)))) : public in *)
  (*         zkp2 ← ZKP (y, (finv f) x) ;; *)
  (*         public ← get public_keys_loc ;; *)
  (*         put public_keys_loc := setm public j (y, zkp2) ;; *)
  (*         put public_keys_loc := (setm (setm m j (y, zkp2)) i zkp1) ;; *)
  (*         keys ← get public_keys_loc ;; *)
  (*         #assert (size (domm keys) == n) ;; *)
  (*         let key := g ^+ (otf x) in *)
  (*           constructed_keys ← get constructed_keys_loc ;; *)
  (*           put constructed_keys_loc := setm constructed_keys i (fto key) ;; *)
  (*           @ret 'unit Datatypes.tt *)
  (*       } *)
  (*   ]. *)

  (* Definition VOTE_E := [interface val #[ VOTE ] : 'bool → 'public]. *)

  (* Definition Vote_i (i : pid) (b : bool) : *)
  (*   package all_locs *)
  (*     [interface] *)
  (*     VOTE_E *)
  (*   := *)
  (*   [package *)
  (*       def #[ VOTE ] (v : 'bool) : 'public *)
  (*       { *)
  (*         skeys ← get secret_keys_loc ;; *)
  (*         #assert (isSome (skeys i)) as x_some ;; *)
  (*         ckeys ← get constructed_keys_loc ;; *)
  (*         #assert (isSome (ckeys i)) as y_some ;; *)
  (*         let x := (getSome (skeys i) x_some) in *)
  (*         let 'y := (getSome (ckeys i) y_some) in *)
  (*         if b then *)
  (*           let vote := ((otf y) ^+ x * g ^+ v) in *)
  (*           @ret 'public (fto vote) *)
  (*         else *)
  (*           let vote := ((otf y) ^+ x * g ^+ (negb v)) in *)
  (*           @ret 'public (fto vote) *)
  (*       } *)
  (*   ]. *)

  (* Equations? P_i (i : pid): *)
  (*   package fset0 *)
  (*     (VOTE_E :|: SETUP_E) *)
  (*     [interface val #[ P i ] : 'bool → 'public] *)
  (*   := P_i i := *)
  (*   [package *)
  (*       def #[ P i ] (v : 'bool) : 'public *)
  (*       { *)
  (*         #import {sig #[ INIT ] : 'unit → 'unit} as Setup ;; *)
  (*         #import {sig #[ VOTE ] : 'bool → 'public} as Vote ;; *)
  (*         Setup Datatypes.tt ;; *)
  (*         vote ← Vote v ;; *)
  (*         @ret 'public vote *)
  (*       } *)
  (*   ]. *)
  (* Proof. *)
  (*   ssprove_valid. *)
  (*   - rewrite in_fsetU ; apply /orP ; right. in_fset_auto. *)
  (*   - rewrite in_fsetU ; apply /orP ; left. *)
  (*     unfold VOTE_E. *)
  (*     rewrite fset_cons -fset0E in_fset. *)
  (*     apply /fset1P. *)
  (*     done. *)
  (* Qed. *)

  Module DDHParams <: DDHParams.
    Definition Space := Secret.
    Definition Space_pos := Secret_pos.
  End DDHParams.

  Module DDH := DDH DDHParams GP.

  #[tactic=notac] Equations? Aux (b : bool) (i j : pid) m f':
    package DDH.DDH_locs
      (DDH.DDH_E :|:
         [interface val #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1]
      )
      [interface val #[ Exec i ] : 'bool → 'public]
    := Aux b i j m f' :=
    [package
        def #[ Exec i ] (v : 'bool) : 'public
        {
          #import {sig #[ DDH.SAMPLE ] : 'unit → 'public × 'public × 'public} as DDH ;;
          #import {sig #[ Sigma1.Sigma.RUN ] : chRelation1 → chTranscript1} as ZKP ;;
          abc ← DDH Datatypes.tt ;;
          x_i ← get DDH.secret_loc1 ;;
          x_j ← get DDH.secret_loc2 ;;
          let '(y_i, (y_j, c)) := abc in
          let y_j' := fto (g ^+ ((finv f') x_j)) in
            zkp1 ← ZKP (y_i, x_i) ;;
            zkp2 ← ZKP (y_j', (finv f') x_j) ;;
            let m' := (setm (setm m j (y_j', zkp2)) i (y_i, zkp1)) in
            #assert (size (domm m') == n) ;;
              @ret 'public (fto ((otf c) *  g ^+ (if b then v else (negb v))))
        }
    ].
  Proof.
    ssprove_valid.
    all: rewrite in_fsetU.
    {
      apply /orP ; left.
      unfold DDH.DDH_E.
      rewrite fset_cons -fset0E fsetU0.
      by apply /fset1P.
    }
    {
      apply /orP ; right.
      rewrite fset_cons -fset0E fsetU0.
      by apply /fset1P.
    }
    {
      apply /orP ; right.
      rewrite fset_cons -fset0E fsetU0.
      by apply /fset1P.
    }
  Qed.

  (* Proof overview: *)
  (* 1: In Setup, the constructed vote can be replace by an random vote *)
  (* 2: P_i \circ (par VOTE_real SETUP_real) ≈ Aux \circ DDH_real *)
  (* 3: P_i \circ (par VOTE_ideal SETUP_real) ≈ Aux \circ DDH_ideal *)

  Module RO1 := Sigma1.Sigma.Oracle.
  Module RO2 := Sigma2.Oracle.

  Definition combined_locations :=
    ((all_locs :|: (Sigma1.MyAlg.Sigma_locs :|: Sigma1.MyAlg.Simulator_locs :|: RO1.RO_locs)) :|:
    ((all_locs :|: (Sigma1.MyAlg.Sigma_locs :|: Sigma1.MyAlg.Simulator_locs :|: RO1.RO_locs)) :|:
     (all_locs :|: (Alg2.Sigma_locs :|: Alg2.Simulator_locs :|: RO2.RO_locs))))
    :|: fset [:: secret_keys_loc].

  Equations? Exec_i_realised b m (i j : pid) : package (P_i_locs i :|: combined_locations) [interface] (Exec_i_E i) :=
    Exec_i_realised b m i j :=
      {package (Exec_i i j m) ∘ (par ((P_i i b) ∘ (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO))
                                      (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO))}.
  Proof.
    ssprove_valid.
    8,13: apply fsubsetxx.
    9: erewrite fsetUid ; apply fsub0set.
    8: erewrite fsetUid ; apply fsubsetxx.
    6: {
      eapply valid_package_inject_locations.
      2: eapply valid_package_inject_export.
      3: eapply valid_package_inject_import.
      4: apply RO1.RO.
      - unfold combined_locations, all_locs.
        rewrite -!fsetUA.
        do 5 (apply fsubsetU; apply /orP ; right).
        apply fsubsetUl.
      - fsubset_auto.
      - rewrite fset0E.
        apply fsubsetxx.
    }
    {
      eapply valid_package_inject_import.
      2:eapply valid_package_inject_export.
      3:apply RO1.RO.
      - rewrite fset0E.
        apply fsubsetxx.
      - fsubset_auto.
    }
    3: apply fsubsetUl.
    3: apply fsubsetUr.
    5: apply fsub0set.
    - unfold combined_locations, all_locs.
      rewrite -!fsetUA.
      do 2 (apply fsubsetU; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations, all_locs.
      rewrite -!fsetUA.
      do 4 (apply fsubsetU; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations, all_locs.
      rewrite -!fsetUA.
      do 3 (apply fsubsetU; apply /orP ; right).
      apply fsubsetUl.
    - unfold EXEC_i_I, P_i_E, Sigma1_I.
      rewrite !fset_cons.
      rewrite -!fsetUA.
      repeat apply fsetUS.
      rewrite -fset0E fsetU0 fset0U.
      apply fsubsetUr.
  Qed.

  #[tactic=notac] Equations? Aux_realised (b : bool) (i j : pid) m f' :
    package (DDH.DDH_locs :|: P_i_locs i :|: combined_locations) Game_import [interface val #[ Exec i ] : 'bool → 'public] :=
    Aux_realised b i j m f' := {package Aux b i j m f' ∘ (par DDH.DDH_real (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO)) }.
  Proof.
    ssprove_valid.
    1: {
      eapply valid_package_inject_export.
      2: apply RO1.RO.
      fsubset_auto.
    }
    4: rewrite -fset0E.
    4: rewrite fsetU0.
    4: apply fsub0set.
    6: apply fsubsetxx.
    3: {
      rewrite fsubUset.
      apply /andP.
      split.
      - rewrite -!fsetUA. apply fsubsetUl.
      - apply fsubsetxx.
    }
    - unfold combined_locations. rewrite -!fsetUA.
      do 4 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations. rewrite -!fsetUA.
      do 6 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold DDH.DDH_E.
      apply fsetUS.
      rewrite !fset_cons.
      apply fsubsetUr.
    - unfold combined_locations. rewrite -!fsetUA.
      apply fsubsetUl.
  Qed.

  #[tactic=notac] Equations? Aux_ideal_realised (b : bool) (i j : pid) m f' :
    package (DDH.DDH_locs :|: P_i_locs i :|: combined_locations) Game_import [interface val #[ Exec i ] : 'bool → 'public] :=
    Aux_ideal_realised b i j m f' := {package Aux b i j m f' ∘ (par DDH.DDH_ideal (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO)) }.
  Proof.
    ssprove_valid.
    1: {
      eapply valid_package_inject_export.
      2: apply RO1.RO.
      fsubset_auto.
    }
    4: rewrite -fset0E.
    4: rewrite fsetU0.
    4: apply fsub0set.
    6: apply fsubsetxx.
    3: {
      rewrite fsubUset.
      apply /andP.
      split.
      - rewrite -!fsetUA. apply fsubsetUl.
      - apply fsubsetxx.
    }
    - unfold combined_locations. rewrite -!fsetUA.
      do 4 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations. rewrite -!fsetUA.
      do 6 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold DDH.DDH_E.
      apply fsetUS.
      rewrite !fset_cons.
      apply fsubsetUr.
    - unfold combined_locations. rewrite -!fsetUA.
      apply fsubsetUl.
  Qed.

  Notation inv i := (heap_ignore (P_i_locs i :|: DDH.DDH_locs)).
  (* Instance Invariant_inv : Invariant combined_locations *)
  (*                                    (DDH.DDH_locs :|: combined_locations) *)
  (*                                    inv. *)
  (* Proof. *)
  (*   ssprove_invariant. *)
  (*   unfold combined_locations, all_locs, secret_locs. *)
  (*   rewrite fset_cons. *)
  (*   rewrite -!fsetUA. *)
  (*   rewrite -fset0E !fset0U. *)
  (*   apply fsetUS. *)
  (*   do 13 (apply fsubsetU ; apply /orP ; right). *)
  (*   apply fsubsetUl. *)
  (* Qed. *)

  Hint Extern 50 (_ = code_link _ _) =>
    rewrite code_link_scheme
    : ssprove_code_simpl.

  (** We extend swapping to schemes.
    This means that the ssprove_swap tactic will be able to swap any command
    with a scheme without asking a proof from the user.
  *)
  Hint Extern 40 (⊢ ⦃ _ ⦄ x ← ?s ;; y ← cmd _ ;; _ ≈ _ ⦃ _ ⦄) =>
    eapply r_swap_scheme_cmd ; ssprove_valid
    : ssprove_swap.


  Lemma P_i_aux_equiv (i j : pid) m:
    fdisjoint Sigma1.MyAlg.Sigma_locs DDH.DDH_locs →
    i != j →
    (∃ f,
      bijective f /\
      (∀ b, (Exec_i_realised b m i j) ≈₀ Aux_realised b i j m f)).
  Proof.
    intros Hdisj ij_neq.
    have [f' Hf] := test_bij' i j m ij_neq.
    simpl in Hf.
    exists f'.
    split.
    {
      assert ('I_#|'I_q'.+2|) as x.
      { rewrite card_ord.
        eapply Ordinal.
        rewrite ltnS.
        apply ltnSn.
      }
      specialize (Hf x).
      destruct Hf.
      assumption.
    }
    intro b.
    eapply eq_rel_perf_ind with (inv := inv i).
    {
      ssprove_invariant.
      rewrite -!fsetUA.
      apply fsetUS.
      do 16 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    }
    simplify_eq_rel v.
    rewrite !setmE.
    rewrite !eq_refl.
    ssprove_code_simpl.
    repeat simplify_linking.
    simpl.
    rewrite !cast_fun_K.
    ssprove_code_simpl.
    ssprove_code_simpl_more.
    ssprove_sync=>x_i.
    ssprove_swap_seq_rhs [:: 4 ; 5 ; 6 ; 7]%N.
    ssprove_swap_seq_rhs [:: 2 ; 3 ; 4 ; 5 ; 6]%N.
    ssprove_swap_seq_rhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5]%N.
    ssprove_contract_put_get_rhs.
    apply r_put_rhs.
    ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3]%N.
    unfold Sigma1.MyParam.R.
    have Hord : ∀ x, (nat_of_ord x) = (nat_of_ord (otf x)).
    {
      unfold otf.
      intros n x.
      rewrite enum_val_ord.
      done.
    }
    rewrite -Hord !otf_fto !eq_refl.
    simpl.
    ssprove_sync=>r_i.
    apply r_put_vs_put.
    ssprove_restore_pre.
    { ssprove_invariant.
      apply preserve_update_r_ignored_heap_ignore.
      - unfold DDH.DDH_locs.
        rewrite in_fsetU.
        apply /orP ; right.
        rewrite fset_cons.
        rewrite in_fsetU.
        apply /orP ; left.
        by apply /fset1P.
      - apply preserve_update_mem_nil.
    }
    ssprove_sync=>queries.
    destruct (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ x_i), fto (g ^+ otf r_i)))) eqn:e.
    all: rewrite e; simpl.
    all: ssprove_code_simpl_more.
    - ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5]%N.
      ssprove_swap_seq_lhs [:: 0 ; 1 ]%N.
      eapply r_uniform_bij.
      { apply Hf.
        + rewrite card_ord.
          rewrite Zp_cast.
          2: apply (prime_gt1 prime_order).
          eapply Ordinal.
          apply (prime_gt1 prime_order).
      }
      intro x.
      specialize (Hf x).
      destruct Hf as [bij_f Hf].
      apply bij_inj in bij_f.
      apply finv_f in bij_f.
      ssprove_contract_put_get_rhs.
      rewrite bij_f.
      rewrite -Hord !otf_fto !eq_refl.
      simpl.
      apply r_put_rhs.
      ssprove_restore_pre.
      {
        apply preserve_update_r_ignored_heap_ignore.
        - unfold DDH.DDH_locs.
          rewrite !fset_cons.
          rewrite !in_fsetU.
          apply /orP ; right.
          apply /orP ; right.
          apply /orP ; left.
          by apply /fset1P.
        - apply preserve_update_mem_nil.
      }
      apply r_get_remember_lhs.
      intros ?.
      apply r_get_remember_rhs.
      intros ?.
      ssprove_forget_all.
      ssprove_sync=>r_j.
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      clear e queries.
      ssprove_sync=>queries.
      destruct (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ x), fto (g ^+ otf r_j)))) eqn:e.
      all: rewrite e.
      all: ssprove_code_simpl.
      all: ssprove_code_simpl_more.
      + ssprove_swap_seq_lhs [:: 0 ; 1]%N.
        simpl.
        apply r_get_remember_lhs.
        intros ?.
        apply r_get_remember_rhs.
        intros ?.
        ssprove_forget_all.
        apply r_assertD.
        {
          intros ??.
          rewrite !domm_set.
          done.
        }
        intros _ _.
        ssprove_swap_lhs 1%N.
        {
          move: H0 => /eqP.
          erewrite eqn_add2r.
          intros contra.
          discriminate.
        }
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          repeat apply preserve_update_l_ignored_heap_ignore.
          1,2: unfold P_i_locs ; rewrite in_fsetU.
          1,2: apply /orP ; left ; rewrite !fset_cons ;
               rewrite -fset0E fsetU0 ; rewrite in_fsetU.
          - apply /orP ; right.
            by apply /fset1P.
          - apply /orP ; left.
            by apply /fset1P.
          - apply preserve_update_mem_nil.
        }
        rewrite otf_fto.
        rewrite compute_key_set_i.
        set zk := (fto (g ^+ x), fto (g ^+ otf r_j), s1, fto (otf x2 + otf s1 * otf x)).
        clearbody zk.
        specialize (Hf zk).
        rewrite !Hord.
        rewrite Hf.
        rewrite -!Hord.
        rewrite -expgM.
        rewrite mulnC.
        case b; apply r_ret ; done.
      + ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3]%N.
        simpl.
        ssprove_sync=>e_j.
        apply r_put_vs_put.
        apply r_get_remember_lhs.
        intros ?.
        apply r_get_remember_rhs.
        intros ?.
        ssprove_forget_all.
        apply r_assertD.
        {
          intros ??.
          rewrite !domm_set.
          done.
        }
        intros _ _.
        ssprove_swap_lhs 1%N.
        {
          move: H0 => /eqP.
          erewrite eqn_add2r.
          intros contra.
          discriminate.
        }
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          repeat apply preserve_update_l_ignored_heap_ignore.
          1,2: unfold P_i_locs ; rewrite in_fsetU.
          1,2: apply /orP ; left ; rewrite !fset_cons ;
               rewrite -fset0E fsetU0 ; rewrite in_fsetU.
          - apply /orP ; right.
            by apply /fset1P.
          - apply /orP ; left.
            by apply /fset1P.
          - ssprove_invariant.
        }
        rewrite otf_fto.
        rewrite compute_key_set_i.
        set zk := (fto (g ^+ x), fto (g ^+ otf r_j), e_j, fto (otf x2 + otf e_j * otf x)).
        clearbody zk.
        specialize (Hf zk).
        rewrite !Hord.
        rewrite Hf.
        rewrite -!Hord.
        rewrite -expgM.
        rewrite mulnC.
        case b; apply r_ret ; done.
    - ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5  ; 6 ; 7]%N.
      ssprove_swap_seq_lhs [:: 2 ; 1 ; 0 ]%N.
      eapply r_uniform_bij.
      { apply Hf.
        + rewrite card_ord.
          rewrite Zp_cast.
          2: apply (prime_gt1 prime_order).
          eapply Ordinal.
          apply (prime_gt1 prime_order).
      }
      intro x.
      specialize (Hf x).
      destruct Hf as [bij_f Hf].
      apply bij_inj in bij_f.
      apply finv_f in bij_f.
      ssprove_contract_put_get_rhs.
      rewrite bij_f.
      rewrite -Hord !otf_fto !eq_refl.
      simpl.
      apply r_put_rhs.
      ssprove_restore_pre.
      {
        apply preserve_update_r_ignored_heap_ignore.
        - unfold DDH.DDH_locs.
          rewrite !fset_cons.
          rewrite !in_fsetU.
          apply /orP ; right.
          apply /orP ; right.
          apply /orP ; left.
          by apply /fset1P.
        - apply preserve_update_mem_nil.
      }
      ssprove_sync=>e_i.
      apply r_put_vs_put.
      apply r_get_remember_lhs.
      intros ?.
      apply r_get_remember_rhs.
      intros ?.
      ssprove_forget_all.
      rewrite -Hord eq_refl.
      simpl.
      ssprove_sync=>r_j.
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      clear e queries.
      ssprove_sync=>queries.
      destruct (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ x), fto (g ^+ otf r_j)))) eqn:e.
      all: rewrite e.
      all: ssprove_code_simpl.
      all: ssprove_code_simpl_more.
      + ssprove_swap_seq_lhs [:: 0 ; 1]%N.
        simpl.
        apply r_get_remember_lhs.
        intros ?.
        apply r_get_remember_rhs.
        intros ?.
        ssprove_forget_all.
        apply r_assertD.
        {
          intros ??.
          rewrite !domm_set.
          done.
        }
        intros _ _.
        ssprove_swap_lhs 1%N.
        {
          move: H0 => /eqP.
          erewrite eqn_add2r.
          intros contra.
          discriminate.
        }
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          repeat apply preserve_update_l_ignored_heap_ignore.
          1,2: unfold P_i_locs ; rewrite in_fsetU.
          1,2: apply /orP ; left ; rewrite !fset_cons ;
               rewrite -fset0E fsetU0 ; rewrite in_fsetU.
          - apply /orP ; right.
            by apply /fset1P.
          - apply /orP ; left.
            by apply /fset1P.
          - apply preserve_update_mem_nil.
        }
        rewrite otf_fto.
        rewrite compute_key_set_i.
        set zk := (fto (g ^+ x), fto (g ^+ otf r_j), s, fto (otf x2 + otf s * otf x)).
        clearbody zk.
        specialize (Hf zk).
        rewrite !Hord.
        rewrite Hf.
        rewrite -!Hord.
        rewrite -expgM.
        rewrite mulnC.
        case b; apply r_ret ; done.
      + ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3]%N.
        simpl.
        ssprove_sync=>e_j.
        apply r_put_vs_put.
        apply r_get_remember_lhs.
        intros ?.
        apply r_get_remember_rhs.
        intros ?.
        ssprove_forget_all.
        apply r_assertD.
        {
          intros ??.
          rewrite !domm_set.
          done.
        }
        intros _ _.
        ssprove_swap_lhs 1%N.
        {
          move: H0 => /eqP.
          erewrite eqn_add2r.
          intros contra.
          discriminate.
        }
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          repeat apply preserve_update_l_ignored_heap_ignore.
          1,2: unfold P_i_locs ; rewrite in_fsetU.
          1,2: apply /orP ; left ; rewrite !fset_cons ;
               rewrite -fset0E fsetU0 ; rewrite in_fsetU.
          - apply /orP ; right.
            by apply /fset1P.
          - apply /orP ; left.
            by apply /fset1P.
          - ssprove_invariant.
        }
        rewrite otf_fto.
        rewrite compute_key_set_i.
        set zk := (fto (g ^+ x), fto (g ^+ otf r_j), e_j, fto (otf x2 + otf e_j * otf x)).
        clearbody zk.
        specialize (Hf zk).
        rewrite !Hord.
        rewrite Hf.
        rewrite -!Hord.
        rewrite -expgM.
        rewrite mulnC.
        case b; apply r_ret ; done.
  Qed.

  Lemma vote_hiding (i j : pid) m:
    i != j →
    ∀ LA A ϵ_DDH,
      ValidPackage LA [interface val #[ Exec i ] : 'bool → 'public] A_export A →
      fdisjoint Sigma1.MyAlg.Sigma_locs DDH.DDH_locs →
      fdisjoint LA DDH.DDH_locs →
      fdisjoint LA (P_i_locs i) →
      fdisjoint LA combined_locations →
      (∀ D, DDH.ϵ_DDH D <= ϵ_DDH) →
    AdvantageE (Exec_i_realised true m i j) (Exec_i_realised false m i j) A <= ϵ_DDH + ϵ_DDH.
  Proof.
    intros ij_neq LA A ϵ_DDH Va Hdisj Hdisj2 Hdisj3 Hdisj4 Dadv.
    have [f' [bij_f Hf]] := P_i_aux_equiv i j m Hdisj ij_neq.
    ssprove triangle (Exec_i_realised true m i j) [::
      (Aux_realised true i j m f').(pack) ;
      (Aux true i j m f') ∘ (par DDH.DDH_ideal (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO)) ;
      (Aux false i j m f') ∘ (par DDH.DDH_ideal (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO)) ;
      (Aux_realised false i j m f').(pack)
    ] (Exec_i_realised false m i j) A as ineq.
    eapply le_trans.
    2: {
      instantiate (1 := 0 + ϵ_DDH + 0 + ϵ_DDH + 0).
      by rewrite ?GRing.addr0 ?GRing.add0r.
    }
    eapply le_trans. 1: exact ineq.
    clear ineq.
    repeat eapply ler_add.
    {
      apply eq_ler.
      specialize (Hf true LA A Va).
      apply Hf.
      - rewrite fdisjointUr.
        apply /andP ; split ; assumption.
      - rewrite fdisjointUr.
        apply /andP ; split.
        2: assumption.
        rewrite fdisjointUr.
        apply /andP ; split ; assumption.
    }
    {
      unfold Aux_realised.
      rewrite -Advantage_link.
      rewrite par_commut.
      have -> : (par DDH.DDH_ideal (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO)) =
               (par (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO) DDH.DDH_ideal).
      { apply par_commut. ssprove_valid. }
      erewrite Advantage_par.
      3: apply DDH.DDH_real.
      3: apply DDH.DDH_ideal.
      2: {
        ssprove_valid.
        - eapply valid_package_inject_export.
          2: apply RO1.RO.
          fsubset_auto.
        - eapply fsubsetUr.
        - apply fsubsetUl.
      }
      1: rewrite Advantage_sym ; apply Dadv.
      - ssprove_valid.
      - unfold trimmed.
        rewrite -link_trim_commut.
        f_equal.
        unfold trim.
        rewrite !fset_cons -fset0E fsetU0.
        rewrite !filterm_set.
        simpl.
        rewrite !in_fsetU !in_fset1 !eq_refl.
        rewrite filterm0.
        done.
      - unfold trimmed.
        unfold trim.
        rewrite !fset_cons -fset0E fsetU0.
        rewrite !filterm_set.
        simpl.
        rewrite !in_fset1 !eq_refl.
        rewrite filterm0.
        done.
      - unfold trimmed.
        unfold trim.
        rewrite !fset_cons -fset0E fsetU0.
        rewrite !filterm_set.
        simpl.
        rewrite !in_fset1 !eq_refl.
        rewrite filterm0.
        done.
    }
    2: {
      unfold Aux_realised.
      rewrite -Advantage_link.
      rewrite par_commut.
      have -> : (par DDH.DDH_real (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO)) =
               (par (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO) DDH.DDH_real).
      { apply par_commut. ssprove_valid. }
      erewrite Advantage_par.
      3: apply DDH.DDH_ideal.
      3: apply DDH.DDH_real.
      2: {
        ssprove_valid.
        - eapply valid_package_inject_export.
          2: apply RO1.RO.
          fsubset_auto.
        - eapply fsubsetUr.
        - apply fsubsetUl.
      }
      1: apply Dadv.
      - ssprove_valid.
      - unfold trimmed.
        rewrite -link_trim_commut.
        f_equal.
        unfold trim.
        rewrite !fset_cons -fset0E fsetU0.
        rewrite !filterm_set.
        simpl.
        rewrite !in_fsetU !in_fset1 !eq_refl.
        rewrite filterm0.
        done.
      - unfold trimmed.
        unfold trim.
        unfold DDH.DDH_E.
        rewrite !fset_cons -fset0E fsetU0.
        rewrite !filterm_set.
        simpl.
        rewrite !in_fset1 !eq_refl.
        rewrite filterm0.
        done.
      - unfold trimmed.
        unfold trim.
        unfold DDH.DDH_E.
        rewrite !fset_cons -fset0E fsetU0.
        rewrite !filterm_set.
        simpl.
        rewrite !in_fset1 !eq_refl.
        rewrite filterm0.
        done.
    }
    2: {
      apply eq_ler.
      specialize (Hf false LA A Va).
      rewrite Advantage_sym.
      apply Hf.
      - rewrite fdisjointUr.
        apply /andP ; split ; assumption.
      - rewrite fdisjointUr.
        apply /andP ; split.
        2: assumption.
        rewrite fdisjointUr.
        apply /andP ; split ; assumption.
    }
    apply eq_ler.
    eapply eq_rel_perf_ind with (inv := inv i).
    5: apply Va.
    1,2: apply Aux_ideal_realised.
    3: {
      rewrite fdisjointUr.
      apply /andP ; split.
      2: assumption.
      rewrite fdisjointUr.
      apply /andP ; split ; assumption.
    }
    3: {
      rewrite fdisjointUr.
      apply /andP ; split.
      2: assumption.
      rewrite fdisjointUr.
      apply /andP ; split ; assumption.
    }
    {
      ssprove_invariant.
      rewrite fsetUC.
      rewrite -!fsetUA.
      apply fsetUS.
      apply fsubsetUl.
    }
    simplify_eq_rel v.
    rewrite !setmE.
    rewrite !eq_refl.
    simpl.
    repeat simplify_linking.
    rewrite !cast_fun_K.
    ssprove_code_simpl.
    ssprove_code_simpl_more.
    ssprove_sync=>x_i.
    ssprove_sync=>x_j.
    pose f_v := (fun (x : secret) =>
                   if v then
                   fto (Zp_add (otf x) Zp1)
                   else
                   fto (Zp_add (otf x) (Zp_opp Zp1))
                ).
    assert (bijective f_v) as bij_fv.
    {
      exists (fun x =>
           if v then
             fto (Zp_add (otf x) (Zp_opp Zp1))
           else
             fto (Zp_add (otf x) Zp1)
        ).
      - intro x.
        unfold f_v.
        case v.
        + rewrite otf_fto.
          rewrite -Zp_addA.
          rewrite Zp_addC.
          have -> : (Zp_add Zp1 (Zp_opp Zp1)) = (Zp_add (Zp_opp Zp1) Zp1).
          { intro n. by rewrite Zp_addC. }
          rewrite Zp_addNz.
          rewrite Zp_add0z.
          by rewrite fto_otf.
        + rewrite otf_fto.
          rewrite -Zp_addA.
          rewrite Zp_addC.
          rewrite Zp_addNz.
          rewrite Zp_add0z.
          by rewrite fto_otf.
      - intro x.
        unfold f_v.
        case v.
        + rewrite otf_fto.
          rewrite -Zp_addA.
          rewrite Zp_addNz.
          rewrite Zp_addC.
          rewrite Zp_add0z.
          by rewrite fto_otf.
        + rewrite otf_fto.
          rewrite -Zp_addA.
          rewrite Zp_addC.
          have -> : (Zp_add Zp1 (Zp_opp Zp1)) = (Zp_add (Zp_opp Zp1) Zp1).
          { intro n. by rewrite Zp_addC. }
          rewrite Zp_addNz.
          rewrite Zp_add0z.
          by rewrite fto_otf.
    }
    eapply r_uniform_bij.
    1: apply bij_fv.
    intro c.
    ssprove_swap_seq_rhs [:: 1 ; 2]%N.
    ssprove_swap_seq_rhs [:: 0 ]%N.
    ssprove_swap_seq_lhs [:: 1 ; 2]%N.
    ssprove_swap_seq_lhs [:: 0 ]%N.
    apply r_put_vs_put.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    unfold Sigma1.MyParam.R.
    have Hord : ∀ x, (nat_of_ord x) = (nat_of_ord (otf x)).
    {
      unfold otf.
      intros n x.
      rewrite enum_val_ord.
      done.
    }
    rewrite -Hord otf_fto eq_refl.
    simpl.
    ssprove_sync=>r_i.
    apply r_put_vs_put.
    ssprove_restore_pre.
    {
      ssprove_invariant.
      apply preserve_update_r_ignored_heap_ignore.
      {
        rewrite in_fsetU.
        apply /orP ; right.
        unfold DDH.DDH_locs.
        rewrite !fset_cons -fset0E fsetU0.
        rewrite in_fsetU.
        apply /orP ; right.
        rewrite in_fsetU.
        apply /orP ; right.
        by apply /fset1P.
      }
      apply preserve_update_l_ignored_heap_ignore.
      2: apply preserve_update_mem_nil.
      rewrite in_fsetU.
      apply /orP ; right.
      unfold DDH.DDH_locs.
      rewrite !fset_cons -fset0E fsetU0.
      rewrite in_fsetU.
      apply /orP ; right.
      rewrite in_fsetU.
      apply /orP ; right.
      by apply /fset1P.
    }
    ssprove_sync=>queries.
    case (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ x_i), fto (g ^+ otf r_i)))) eqn:e.
    all: rewrite e.
    all: ssprove_code_simpl ; simpl.
    all: ssprove_code_simpl_more ; simpl.
    - apply r_get_remember_lhs.
      intros ?.
      apply r_get_remember_rhs.
      intros ?.
      ssprove_forget_all.
      rewrite -Hord otf_fto eq_refl.
      simpl.
      ssprove_sync=>e_j.
      apply r_put_lhs.
      apply r_put_rhs.
      clear e queries.
      ssprove_restore_pre.
      1: ssprove_invariant.
      ssprove_sync=>queries.
      case (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ finv f' x_j), fto (g ^+ otf e_j)))) eqn:e.
      all: rewrite e.
      all: simpl; ssprove_code_simpl.
      all: ssprove_code_simpl_more.
      + apply r_get_remember_lhs.
        intros ?.
        apply r_get_remember_rhs.
        intros ?.
        ssprove_forget_all.
        apply r_assertD.
        {
          intros ??.
          rewrite !domm_set.
          done.
        }
        intros _ _.
        apply r_ret.
        intros ???.
        split.
        2: assumption.
        unfold f_v.
        rewrite !otf_fto.
        rewrite -!expgD.
        have h' : ∀ (x : Secret), nat_of_ord x = (nat_of_ord (fto x)).
        {
          unfold fto.
          intros k.
          rewrite enum_rank_ord.
          done.
        }
        case v.
        ++ simpl.
           f_equal.
           apply /eqP.
           rewrite eq_expg_mod_order.
           rewrite addn0.
           clear Hdisj Hdisj2 Hdisj3 Hdisj4 e bij_fv f_v Dadv hin Hf bij_f f' Va H.
           have h : ∀ (x : secret), (((nat_of_ord x) + 1) %% q'.+2)%N = (nat_of_ord (Zp_add (otf x) Zp1)).
           {
             intro k.
             unfold Zp_add.
             simpl.
             (* rewrite -modZp. *)
             rewrite -Hord.
             apply /eqP.
             rewrite eq_sym.
             apply /eqP.
             have -> : (1 %% q'.+2 = 1)%N.
             - rewrite modn_small.
               + reflexivity.
               + apply prime_gt1.
                 unfold q'.
                 rewrite -subn2 -addn2.
                 rewrite subnK.
                 1: apply prime_order.
                 apply (prime_gt1 prime_order).
             - reflexivity.
           }
           rewrite -h'.
           rewrite -h.
           rewrite -modn_mod.
           unfold q'.
           rewrite -subn2 -addn2.
           rewrite subnK.
           1: apply eq_refl.
           apply (prime_gt1 prime_order).
        ++ simpl.
           f_equal.
           apply /eqP.
           rewrite eq_expg_mod_order.
           rewrite addn0.
           unfold Zp_add, Zp_opp, Zp1.
           simpl.
           rewrite -!Hord.
           simpl.
           have -> : (q'.+2 - 1 %% q'.+2)%N = q'.+1.
           { rewrite modn_small.
             2: {
               apply prime_gt1.
               unfold q'.
               rewrite -subn2 -addn2.
               rewrite subnK.
               1: apply prime_order.
               apply (prime_gt1 prime_order).
             }
             done.
           }
           simpl.
           rewrite modn_small.
           2:{
             destruct c as [c Hc].
             move: Hc.
             simpl.
             unfold DDH.i_space, DDHParams.Space, Secret.
             rewrite card_ord.
             unfold q'.
             rewrite -subn2 -addn2.
             rewrite subnK.
             1: done.
             apply (prime_gt1 prime_order).
           }
           have -> : (q'.+1 %% q'.+2)%N = q'.+1.
           {
             rewrite modn_small.
             1: reflexivity.
             apply ltnSn.
           }
           rewrite -h'.
           simpl.
           have Hq : q'.+2 = #[g].
           {
             unfold q'.
             rewrite -subn2 -addn2.
             rewrite subnK.
             1: reflexivity.
             apply (prime_gt1 prime_order).
           }
           rewrite -> Hq at 6.
           rewrite modnDml.
           rewrite -addnA.
           rewrite addn1.
           rewrite -modnDmr.
           rewrite -> Hq at 6.
           rewrite modnn.
           rewrite addn0.
           rewrite modn_small.
           1: apply eq_refl.
           destruct c as [h Hc].
           move: Hc.
           unfold DDH.i_space, DDHParams.Space, Secret.
           simpl.
           rewrite card_ord.
           rewrite Hq.
           done.



  #[tactic=notac] Equations? P_i_realised (i j : pid) (b : bool) m:
    package combined_locations Game_import [interface val #[ P i ] : 'bool → 'public] :=
    P_i_realised i j b m :=
      {package P_i i ∘ (par (Vote_i i b)
                            (SETUP_real m i j ∘ (Sigma1.Sigma.Fiat_Shamir) ∘ RO1.RO))}.
  Proof.
    ssprove_valid.
    10: apply fsubsetxx.
    {
      eapply valid_package_inject_export.
      2: apply RO1.RO.
      fsubset_auto.
    }
    8: apply fsub0set.
    4,7: apply fsubsetxx.
    4: {
      instantiate (1 := combined_locations).
      rewrite fsubUset.
      apply /andP ; split.
      2: apply fsubsetxx.
      unfold combined_locations, all_locs. rewrite -!fsetUA.
      apply fsetUS.
      apply fsubsetUl.
    }
    - unfold combined_locations. rewrite -!fsetUA.
      do 2 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations. rewrite -!fsetUA.
      do 4 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations, all_locs.
      rewrite -!fsetUA.
      apply fsetUS.
      apply fsubsetUl.
    - rewrite -fset0E fset0U. apply fsub0set.
  Qed.

  #[tactic=notac] Equations? P_i_aux (i j : pid) m f:
    package combined_locations Game_import [interface val #[ P i ] : 'bool → 'public] :=
    P_i_aux i j m f :=
      {package P_i i ∘ (par (Vote_i i true)
                            (SETUP_ideal m i j f ∘ (Sigma1.Sigma.Fiat_Shamir) ∘ RO1.RO))}.
  Proof.
    ssprove_valid.
    {
      eapply valid_package_inject_export.
      2: exact _.
      fsubset_auto.
    }
    4,7,9: apply fsubsetxx.
    6: apply fsub0set.
    4: {
      rewrite fsubUset.
      apply /andP ; split.
      2: apply fsubsetxx.
      unfold combined_locations, all_locs. rewrite -!fsetUA.
      apply fsetUS.
      apply fsubsetUl.
    }
    - unfold combined_locations. rewrite -!fsetUA.
      do 2 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations. rewrite -!fsetUA.
      do 4 (apply fsubsetU ; apply /orP ; right).
      apply fsubsetUl.
    - unfold combined_locations, all_locs.
      rewrite -!fsetUA.
      apply fsetUS.
      apply fsubsetUl.
    - rewrite -fset0E fset0U. apply fsub0set.
  Qed.

  Lemma P_i_aux_equiv (i j : pid) m f':
    fdisjoint Sigma1.MyAlg.Sigma_locs DDH.DDH_locs →
    bijective f' →
    i != j →
    (P_i_aux i j m f') ≈₀ Aux_realised i j m f'.
  Proof.
    intros Hdisj bij_f' ij_neq.
    have Hne : (i == j) = false.
    {
      case (eq_op) eqn:e.
      - discriminate.
      - reflexivity.
    }
    clear ij_neq.
    eapply eq_rel_perf_ind with (inv := inv). 1: exact _.
    simplify_eq_rel v.
    rewrite !setmE.
    rewrite !eq_refl.
    simpl.
    repeat simplify_linking.
    rewrite !cast_fun_K.
    ssprove_code_simpl.
    ssprove_code_simpl_more.
    ssprove_sync=>x_i.
    apply r_get_remember_lhs.
    intro skeys.
    ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3]%N.
    ssprove_swap_seq_rhs [:: 4 ; 5 ; 6 ; 7]%N.
    ssprove_swap_seq_rhs [:: 2 ; 3 ; 4 ; 5 ; 6]%N.
    ssprove_swap_seq_rhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5]%N.
    ssprove_contract_put_get_rhs.
    unfold Sigma1.MyParam.R.
    have Hord : ∀ x, (nat_of_ord x) = (nat_of_ord (otf x)).
    {
      unfold otf.
      intros n x.
      rewrite enum_val_ord.
      done.
    }
    rewrite -Hord !otf_fto !eq_refl.
    simpl.
    apply r_put_rhs.
    ssprove_sync=>r_i.
    apply r_put_vs_put.
    ssprove_restore_mem.
    {
      ssprove_invariant.
      apply preserve_update_r_ignored_heap_ignore.
      {
        unfold DDH.DDH_locs.
        rewrite in_fsetU.
        apply /orP ; right.
        rewrite fset_cons.
        rewrite in_fsetU.
        apply /orP ; left.
        by apply /fset1P.
      }
      apply preserve_update_mem_nil.
    }
    ssprove_sync=>queries.
    destruct (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ x_i), fto (g ^+ otf r_i)))) eqn:e.
    all: rewrite e.
    all: simpl.
    all: ssprove_code_simpl ; ssprove_code_simpl_more.
    - ssprove_swap_seq_rhs [:: 2 ; 3 ; 4 ]%N.
      ssprove_swap_seq_rhs [:: 1 ; 2 ; 3 ]%N.
      ssprove_swap_seq_rhs [:: 0 ; 1 ; 2 ]%N.
      ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ]%N.
      apply r_get_vs_get_remember_lhs.
      { ssprove_invariant.
        move: Hdisj => /fdisjointP Hdisj.
        apply Hdisj.
        unfold Sigma1.MyAlg.Sigma_locs.
        rewrite -fset1E in_fset1.
        apply eq_refl.
      }
      intro e_i.
      ssprove_forget.
      ssprove_sync=>pkeys.
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      ssprove_sync=>x_j.
      ssprove_contract_put_get_lhs.
      ssprove_contract_put_get_rhs.
      apply r_put_lhs.
      apply r_put_rhs.
      ssprove_forget_all.
      ssprove_restore_pre.
      {
        apply preserve_update_r_ignored_heap_ignore.
        {
          unfold DDH.DDH_locs.
          rewrite in_fsetU.
          apply /orP ; right.
          rewrite fset_cons.
          rewrite in_fsetU.
          apply /orP ; right.
          rewrite fset_cons.
          rewrite in_fsetU.
          apply /orP ; left.
          by apply /fset1P.
        }
        apply preserve_update_l_ignored_heap_ignore.
        {
          unfold secret_locs.
          rewrite in_fsetU.
          apply /orP ; left.
          rewrite -fset1E.
          by apply /fset1P.
        }
        apply preserve_update_mem_nil.
      }
      rewrite -!Hord !otf_fto !eq_refl.
      simpl.
      ssprove_swap_seq_lhs [:: 0 ; 1 ; 2]%N.
      ssprove_sync=>r_j.
      apply r_put_vs_put.
      clear e queries.
      ssprove_restore_pre.
      1: ssprove_invariant.
      ssprove_sync=>queries.
      case (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ (finv f') x_j), fto (g ^+ otf r_j)))) eqn:e.
      + rewrite !e.
        simpl.
        ssprove_code_simpl_more.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7 ]%N.
        apply r_get_vs_get_remember.
        {
          ssprove_invariant.
          move: Hdisj => /fdisjointP Hdisj.
          apply Hdisj.
          unfold Sigma1.MyAlg.Sigma_locs.
          rewrite -fset1E in_fset1.
          apply eq_refl.
        }
        intro e_j.
        ssprove_forget_all.
        apply r_get_vs_get_remember.
        1: ssprove_invariant.
        clear pkeys. intro pkeys.
        ssprove_forget_all.
        ssprove_contract_put_lhs.
        ssprove_contract_put_rhs.
        ssprove_contract_put_get_lhs.
        ssprove_contract_put_get_rhs.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        ssprove_sync=>all_votes.
        apply r_get_vs_get_remember.
        1: ssprove_invariant.
        intro ckeys.
        ssprove_forget_all.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2]%N.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          apply preserve_update_l_ignored_heap_ignore.
          {
            unfold secret_locs.
            rewrite in_fsetU.
            apply /orP ; left.
            rewrite -fset1E.
            by apply /fset1P.
          }
          apply preserve_update_mem_nil.
        }
        ssprove_swap_seq_lhs [:: 0 ; 1]%N.
        ssprove_contract_put_get_lhs.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        rewrite !setmE !eq_refl Hne.
        simpl.
        apply r_ret.
        rewrite otf_fto -expgM.
        rewrite mulnC.
        done.
      + rewrite e.
        simpl.
        ssprove_code_simpl_more.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7 ; 8 ; 9]%N.
        ssprove_sync=>e_j.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        apply r_get_vs_get_remember.
        {
          ssprove_invariant.
          move: Hdisj => /fdisjointP Hdisj.
          apply Hdisj.
          unfold Sigma1.MyAlg.Sigma_locs.
          rewrite -fset1E in_fset1.
          apply eq_refl.
        }
        intros ?.
        ssprove_forget_all.
        apply r_get_vs_get_remember.
        1: ssprove_invariant.
        clear pkeys. intros pkeys.
        ssprove_forget_all.
        ssprove_contract_put_lhs.
        ssprove_contract_put_rhs.
        ssprove_contract_put_get_lhs.
        ssprove_contract_put_get_rhs.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        ssprove_sync=>all_votes.
        ssprove_sync=>ckeys.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ]%N.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          apply preserve_update_l_ignored_heap_ignore.
          {
            unfold secret_locs.
            rewrite in_fsetU.
            apply /orP ; left.
            rewrite -fset1E.
            by apply /fset1P.
          }
          apply preserve_update_mem_nil.
        }
        rewrite !setmE !eq_refl Hne.
        simpl.
        ssprove_contract_put_get_lhs.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        rewrite !setmE !eq_refl.
        simpl.
        apply r_ret.
        rewrite otf_fto -expgM mulnC.
        done.
    - ssprove_swap_seq_rhs [:: 2 ; 3 ; 4 ]%N.
      ssprove_swap_seq_rhs [:: 1 ; 2 ; 3 ]%N.
      ssprove_swap_seq_rhs [:: 0 ; 1 ; 2 ]%N.
      ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ]%N.
      ssprove_sync=>e_i.
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      apply r_get_vs_get_remember_lhs.
      { ssprove_invariant.
        move: Hdisj => /fdisjointP Hdisj.
        apply Hdisj.
        unfold Sigma1.MyAlg.Sigma_locs.
        rewrite -fset1E in_fset1.
        apply eq_refl.
      }
      intros ?.
      ssprove_swap_seq_lhs [:: 2 ; 1 ; 0]%N.
      ssprove_sync=>x_j.
      ssprove_swap_seq_lhs [:: 2 ; 0 ; 1]%N.
      ssprove_contract_put_get_lhs.
      ssprove_contract_put_get_rhs.
      ssprove_swap_seq_lhs [:: 2 ; 1]%N.
      ssprove_contract_put_lhs.
      apply r_put_rhs.
      ssprove_forget_all.
      ssprove_restore_mem.
      {
        apply preserve_update_r_ignored_heap_ignore.
        {
          unfold DDH.DDH_locs.
          rewrite in_fsetU.
          apply /orP ; right.
          rewrite fset_cons.
          rewrite in_fsetU.
          apply /orP ; right.
          rewrite fset_cons.
          rewrite in_fsetU.
          apply /orP ; left.
          by apply /fset1P.
        }
        apply preserve_update_mem_nil.
      }
      ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5]%N.
      ssprove_sync=>pkeys.
      apply r_put_vs_put.
      rewrite -!Hord !otf_fto !eq_refl.
      simpl.
      ssprove_sync=>r_j.
      apply r_put_vs_put.
      clear e queries.
      ssprove_restore_pre.
      1: ssprove_invariant.
      ssprove_sync=>queries.
      case (queries (Sigma1.Sigma.prod_assoc (fto (g ^+ finv f' x_j), fto (g ^+ otf r_j)))) eqn:e.
      + rewrite !e.
        simpl.
        ssprove_code_simpl_more.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7]%N.
        apply r_get_vs_get_remember.
        {
          ssprove_invariant.
          move: Hdisj => /fdisjointP Hdisj.
          apply Hdisj.
          unfold Sigma1.MyAlg.Sigma_locs.
          rewrite -fset1E in_fset1.
          apply eq_refl.
        }
        intro e_j.
        ssprove_forget_all.
        apply r_get_vs_get_remember.
        1: ssprove_invariant.
        clear pkeys. intro pkeys.
        ssprove_contract_put_lhs.
        ssprove_contract_put_rhs.
        ssprove_contract_put_get_lhs.
        ssprove_contract_put_get_rhs.
        ssprove_forget_all.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        ssprove_sync=>all_votes.
        apply r_get_vs_get_remember.
        1: ssprove_invariant.
        intro ckeys.
        ssprove_forget_all.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2]%N.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          apply preserve_update_l_ignored_heap_ignore.
          {
            unfold secret_locs.
            rewrite in_fsetU.
            apply /orP ; left.
            rewrite -fset1E.
            by apply /fset1P.
          }
          apply preserve_update_mem_nil.
        }
        ssprove_swap_seq_lhs [:: 0 ; 1]%N.
        ssprove_contract_put_get_lhs.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        rewrite !setmE !eq_refl Hne.
        simpl.
        apply r_ret.
        rewrite otf_fto -expgM.
        rewrite mulnC.
        done.
      + rewrite e.
        simpl.
        ssprove_code_simpl_more.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7 ; 8 ; 9]%N.
        ssprove_sync=>e_j.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        apply r_get_vs_get_remember.
        {
          ssprove_invariant.
          move: Hdisj => /fdisjointP Hdisj.
          apply Hdisj.
          unfold Sigma1.MyAlg.Sigma_locs.
          rewrite -fset1E in_fset1.
          apply eq_refl.
        }
        intros ?.
        ssprove_forget_all.
        apply r_get_vs_get_remember.
        1: ssprove_invariant.
        clear pkeys. intros pkeys.
        ssprove_forget_all.
        ssprove_contract_put_lhs.
        ssprove_contract_put_rhs.
        ssprove_contract_put_get_lhs.
        ssprove_contract_put_get_rhs.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        ssprove_sync=>all_votes.
        ssprove_sync=>ckeys.
        ssprove_swap_seq_lhs [:: 0 ; 1 ; 2 ]%N.
        ssprove_contract_put_get_lhs.
        apply r_put_lhs.
        ssprove_restore_pre.
        {
          apply preserve_update_l_ignored_heap_ignore.
          {
            unfold secret_locs.
            rewrite in_fsetU.
            apply /orP ; left.
            rewrite -fset1E.
            by apply /fset1P.
          }
          apply preserve_update_mem_nil.
        }
        rewrite !setmE !eq_refl Hne.
        simpl.
        ssprove_contract_put_get_lhs.
        apply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        rewrite !setmE !eq_refl.
        simpl.
        apply r_ret.
        rewrite otf_fto -expgM mulnC.
        done.
  Qed.

  Lemma constructed_key_random m (i j : pid):
    (i != j)%N →
    ∃ f,
      bijective f /\
    ∀ LA A LSim Sim ϵ_zk,
      ValidPackage LA SETUP_E A_export A →
      fdisjoint LA (LSim :|: combined_locations) →
      fdisjoint LSim secret_locs →
      (∀ D, Sigma1.Sigma.ϵ_fiat_shamir_zk LSim Sim D <= ϵ_zk) →
        AdvantageE (SETUP_realised true m i j f) (SETUP_realised false m i j f) A <=
          ϵ_zk + ϵ_zk.
    (* (SETUP_realised true m i j f) ≈₀ (SETUP_realised false m i j f). *)
  Proof.
    intro ne.
    have [f' Hf] := test_bij' i j m ne.
    simpl in Hf.
    exists f'.
    split.
    {
      assert ('I_#|'I_q'.+2|) as x.
      - rewrite card_ord.
        eapply Ordinal.
        instantiate (1 := q'.+1).
        rewrite ltnS.
        apply ltnSn.
      - specialize (Hf x).
        destruct Hf.
        assumption.
    }
    intros LA A LSim Sim ϵ_zk Va Hdisj Hdisj_secret Dadv.
    ssprove triangle (SETUP_realised true m i j f') [::
      (SETUP_real m i j ∘ (Sigma1.Sigma.Fiat_Shamir_SIM LSim Sim) ∘ RO1.RO) ;
      (SETUP_ideal m i j f' ∘ (Sigma1.Sigma.Fiat_Shamir_SIM LSim Sim) ∘ RO1.RO)
    ] (SETUP_realised false m i j f') A as ineq.
    eapply le_trans.
    2: {
      instantiate (1 := ϵ_zk + 0 + ϵ_zk).
      by rewrite GRing.addr0.
    }
    eapply le_trans. 1: exact ineq.
    clear ineq.
    repeat eapply ler_add.
    {
      unfold SETUP_realised.
      rewrite -Advantage_link.
      specialize (Dadv (A ∘ SETUP_real m i j)).
      eapply le_trans.
      2: apply Dadv.
      done.
    }
    2:{
      unfold SETUP_realised.
      rewrite -Advantage_link.
      rewrite -Advantage_sym.
      specialize (Dadv (A ∘ SETUP_ideal m i j f')).
      eapply le_trans.
      2: apply Dadv.
      done.
    }
    apply eq_ler.
    eapply eq_rel_perf_ind.
    6,7: apply Hdisj.
    3: {
      instantiate (1 := heap_ignore secret_locs).
      ssprove_invariant.
      erewrite fsetUid.
      unfold combined_locations, all_locs, secret_locs.
      rewrite fset_cons.
      rewrite -!fsetUA.
      apply fsubsetU; apply /orP; right.
      apply fsetUSS.
      - rewrite fset1E. apply fsubsetxx.
      - apply fsubsetU.
        apply /orP ; left.
        apply fsubsetxx.
    }
    4: apply Va.
    {
      ssprove_valid.
      {
        eapply valid_package_inject_export.
        2: exact _.
        all: fsubset_auto.
      }
      1: eapply fsubsetUl.
      1: apply fsubsetUr.
      {
        unfold combined_locations, all_locs.
        apply fsubsetU ; apply /orP ; right.
        rewrite -!fsetUA.
        apply fsetUS.
        apply fsubsetUl.
      }
      {
        apply fsetUS.
        unfold combined_locations, RO1.RO_locs.
        rewrite -!fsetUA.
        do 4 (apply fsubsetU ; apply /orP ; right).
        apply fsubsetUl.
      }
    }
    {
      ssprove_valid.
      {
        eapply valid_package_inject_export.
        2: exact _.
        all: fsubset_auto.
      }
      1: eapply fsubsetUl.
      1: apply fsubsetUr.
      {
        unfold combined_locations, all_locs.
        apply fsubsetU ; apply /orP ; right.
        rewrite -!fsetUA.
        apply fsetUS.
        apply fsubsetUl.
      }
      {
        apply fsetUS.
        unfold combined_locations, RO1.RO_locs.
        rewrite -!fsetUA.
        do 4 (apply fsubsetU ; apply /orP ; right).
        apply fsubsetUl.
      }
    }
    simplify_eq_rel t.
    ssprove_code_simpl.
    rewrite !cast_fun_K.
    ssprove_code_simpl.
    ssprove_code_simpl_more.
    ssprove_sync=>x_i.
    apply r_get_remember_lhs=>sks_lhs.
    apply r_get_remember_rhs=>sks_rhs.
    ssprove_forget_all.
    apply r_put_lhs.
    apply r_put_rhs.
    ssprove_sync=>rel_i.
    ssprove_code_simpl.
    ssprove_restore_pre.
    { ssprove_invariant. }
    eapply rsame_head_alt.
    1: exact _.
    {
      intros l lin.
      apply get_pre_cond_heap_ignore.
      move: Hdisj_secret => /fdisjointP Hdisj_secret.
      apply Hdisj_secret.
      assumption.
    }
    {
      intros l v lin.
      apply put_pre_cond_heap_ignore.
    }
    intro zkp_i.
    ssprove_sync=>pkeys.
    apply r_put_vs_put.
    ssprove_restore_pre.
    { ssprove_invariant. }
    eapply r_uniform_bij.
    { apply Hf.
      + rewrite card_ord.
        rewrite Zp_cast.
        2: apply (prime_gt1 prime_order).
        eapply Ordinal.
        apply (prime_gt1 prime_order).
    }
    intro x.
    clear sks_lhs sks_rhs.
    apply r_get_remember_lhs=>sks_lhs.
    apply r_get_remember_rhs=>sks_rhs.
    ssprove_forget_all.
    apply r_put_lhs.
    apply r_put_rhs.
    ssprove_code_simpl_more.
    apply r_assertD.
    {
      intros [s0 s1] _.
      unfold Sigma1.MyParam.R.
      rewrite !otf_fto !eq_refl.
      reflexivity.
    }
    intros _ _.
    ssprove_code_simpl.
    specialize (Hf x).
    destruct Hf as [bij_f Hf].
    apply bij_inj in bij_f.
    apply finv_f in bij_f.
    rewrite !bij_f.
    ssprove_restore_pre.
    1: ssprove_invariant.
    eapply rsame_head_alt.
    1: exact _.
    {
      intros l lin.
      apply get_pre_cond_heap_ignore.
      move: Hdisj_secret => /fdisjointP Hdisj_secret.
      apply Hdisj_secret.
      assumption.
    }
    {
      intros l v lin.
      apply put_pre_cond_heap_ignore.
    }
    intro zkp_j.
    clear pkeys.
    ssprove_sync=>pkeys.
    apply r_put_vs_put.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_restore_pre.
    { ssprove_invariant. }
    (* TODO: ssprove_code_simpl_more fails here. *)
    eapply rel_jdg_replace_sem.
    2: {
      ssprove_code_simpl_more_aux.
      eapply rreflexivity_rule.
    }
    2: {
      ssprove_code_simpl_more_aux.
      eapply rreflexivity_rule.
    }
    cmd_bind_simpl ; cbn beta.
    ssprove_sync=>_.
    apply r_get_vs_get_remember.
    1: ssprove_invariant.
    intro ckeys.
    rewrite compute_key_set_i.
    specialize (Hf zkp_j).
    rewrite Hf.
    apply r_put_vs_put.
    ssprove_restore_mem.
    1: ssprove_invariant.
    apply r_ret ; done.
  Qed.

  Lemma vote_random m (i j : pid):
    (i != j)%N →
    ∀ LA A LSim Sim ϵ_zk,
      ValidPackage LA [interface val #[ P i ] : 'bool → 'public] A_export A →
      fdisjoint LA combined_locations →
      fdisjoint LA LSim →
      fdisjoint LA DDH.DDH_locs →
      fdisjoint LSim secret_locs →
      fdisjoint Sigma1.MyAlg.Sigma_locs DDH.DDH_locs →
      (∀ D, Sigma1.Sigma.ϵ_fiat_shamir_zk LSim Sim D <= ϵ_zk) →
    AdvantageE (P_i_realised i j true m) (P_i_realised i j false m) A <=
      ϵ_zk + ϵ_zk.
    (* (SETUP_realised true m i j f) ≈₀ (SETUP_realised false m i j f). *)
  Proof.
    intros ij_neq LA A LSim Sim ϵ_zk Va Hdisj1 Hdisj2 Hdisj3 Hdisj4 Hdisj5 Dadv.
    have [f' [bij_f' H]] := constructed_key_random m i j ij_neq.
    ssprove triangle (P_i_realised i j true m) [::
      (P_i_aux i j m f').(pack) ;
      (Aux_realised i j m f').(pack)
    ] (P_i_realised i j false m) A as ineq.
    eapply le_trans.
    2: {
      instantiate (1 := (ϵ_zk + ϵ_zk) + 0 + 0).
      by rewrite ?GRing.addr0 ?GRing.add0r.
    }
    eapply le_trans. 1: exact ineq.
    clear ineq.
    repeat eapply ler_add.
    2: {
      have H' := P_i_aux_equiv i j m f' Hdisj5 bij_f' ij_neq.
      specialize (H' LA A Va).
      apply eq_ler.
      apply H'.
      - assumption.
      - rewrite fdisjointUr.
        apply /andP ; split ; assumption.
    }
    {
      (* unfold P_i_realised. *)
      (* unfold P_i_aux. *)
      rewrite -!Advantage_link.
      erewrite Advantage_par.
      {
        unfold SETUP_realised in H.
        eapply H.
        {
          rewrite -link_assoc.
          eapply valid_link.
          1: apply Va.
          eapply valid_link.
          1: exact _.
          eapply valid_package_inject_import.
          2: eapply valid_par.
          3: exact _.
          - rewrite -fset0E fset0U.
            apply fsubsetxx.
          - eapply parable.
          - apply valid_ID.
            eapply flat_valid_package.
            apply SETUP_real.
        }
        3: apply Dadv.
        2: assumption.
        rewrite fset0U.
        2: {
          rewrite fdisjointUr.
          apply /andP ; split ; eassumption.
        }
        eapply valid_package_inject_locations.
        2: eapply valid_link.
        2: {
          eapply valid_package_inject_locations.
          2: eapply valid_link.
          2: apply Va.
          2: exact _.
          rewrite fsetU0.
          apply fsubsetxx.
        }
        ssprove_valid.
        1,7,8: apply fsubsetxx.
        1: apply fsub0set.
        - rewrite domm_ID domm_set domm0.
          simpl.
          unfold SETUP_E.
          rewrite fsetU0.
          rewrite fset_cons -fset0E.
          rewrite fsetU0.
          simpl.
          unfold FDisjoint.
          rewrite fdisjoint1s.
          rewrite -fset1E.
          apply /fset1P.
          done.
        - eapply flat_valid_package ; apply SETUP_real.
        -
      }
    }
    eapply le_trans. 1: exact: ineq.
    clear ineq.
    apply ler_naddr; last first.
    {
      have :=
    }
    all: apply eq_ler.

  Notation inv := (heap_ignore secret_locs).

  Proof.
    ssprove_invariant.
    unfold combined_locations, all_locs, secret_locs.
    rewrite fset_cons.
    rewrite -!fsetUA.
    apply fsetUSS.
    - rewrite fset1E. apply fsubsetxx.
    - apply fsubsetU.
      apply /orP ; left.
      apply fsubsetxx.
  Qed.

  Lemma notin_inv_helper :
    ∀ l,
      l != secret_keys_loc →
      (is_true (l \notin secret_locs)).
  Proof.
    intros l h1.
    unfold secret_locs.
    unfold "\notin".
    rewrite !fset_cons -fset0E.
    rewrite in_fset.
    unfold "\in".
    simpl.
    apply /orP.
    unfold not.
    intros [H |] .
    - apply reflection_nonsense in H.
      rewrite H in h1.
      by rewrite eq_refl in h1.
    - done.
  Qed.

  #[local] Hint Extern 3 (is_true (?l \notin (fset [:: secret_keys_loc]))) =>
    apply notin_inv_helper : typeclass_instances ssprove_valid_db ssprove_invariant.

  Lemma constructed_key_random :
    SETUP_realised true  ≈₀ SETUP_realised false.
  Proof.
  intros l A Va Hdisj1 Hdisj2.
  ssprove triangle (SETUP_realised true) [::
        (SETUP_aux).(pack) ∘ (par (Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO_Random) Ledger)
      ] (SETUP_realised false) A as ineq.
  apply AdvantageE_le_0.
  eapply ler_trans. 1: exact: ineq.
  clear ineq.
  apply ler_naddr; last first.
  all: apply eq_ler.
  - eapply eq_rel_perf_ind with (inv := inv).
    1,3,5: exact _.
    3,4: assumption.
    1: {
      ssprove_valid.
      {
        eapply valid_package_inject_export.
        2: apply RO1.RO_Random.
        fsubset_auto.
      }
      7: apply fsubsetxx.
      1: instantiate (1 := (Sigma1.MyAlg.Sigma_locs :|: RO1.RO_locs)).
      - apply fsubsetUl.
      - apply fsubsetUr.
      - unfold combined_locations, all_locs.
        rewrite -!fsetUA.
        do 3 (apply fsubsetU; apply /orP ; right).
        apply fsetUS.
        do 1 (apply fsubsetU; apply /orP ; right).
        apply fsetUS.
        do 2 (apply fsubsetU; apply /orP ; right).
        apply fsubsetUl.
      - rewrite -fset0E fsetU0. apply fsub0set.
      - rewrite !fset_cons !fset1E.
        rewrite -!fsetUA.
        rewrite fsubUset. apply /andP ; split.
        1: apply fsubsetU ; apply /orP ; right ; apply fsubsetUl.
        apply fsetUS.
        rewrite fsubUset. apply /andP ; split.
        + do 2 (apply fsubsetU; apply /orP ; right).
          apply fsubsetUl.
        + do 4 (apply fsubsetU; apply /orP ; right).
          rewrite -fset0E fsetU0.
          apply fsubsetUl.
      - unfold combined_locations, all_locs.
        rewrite -!fsetUA.
        apply fsetUS.
        apply fsubsetUl.
    }
    simplify_eq_rel ij.
    ssprove_code_simpl.
    rewrite !cast_fun_K.
    destruct ij as [i j].
    ssprove_code_simpl.
    ssprove_code_simpl_more.
    ssprove_code_simpl.
    ssprove_sync=>x_i.
    apply r_get_remember_lhs=>skeys_lhs.
    apply r_get_remember_rhs=>skeys_rhs.
    ssprove_forget_all.
    ssprove_swap_seq_lhs [:: 8 ; 7 ; 6 ; 5 ; 4 ; 3 ; 2 ; 1]%N.
    ssprove_swap_seq_rhs [:: 8 ; 7 ; 6 ; 5 ; 4 ; 3 ; 2 ; 1]%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>rel_i.
    ssprove_sync=>r_i.
    ssprove_swap_lhs 1%N.
    ssprove_swap_rhs 1%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>e_i.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_sync=>pkeys.
    ssprove_swap_seq_lhs [:: 7 ; 6 ; 5 ; 4 ; 3 ; 2 ; 1]%N.
    ssprove_swap_seq_rhs [:: 7 ; 6 ; 5 ; 4 ; 3 ; 2 ; 1]%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>x_j.
    apply r_put_vs_put.
    ssprove_sync=>rel_j.
    ssprove_sync=>r_j.
    ssprove_swap_lhs 1%N.
    ssprove_swap_rhs 1%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>e_j.
    ssprove_swap_seq_lhs [:: 4 ; 3 ; 2 ; 1]%N.
    ssprove_swap_seq_rhs [:: 4 ; 3 ; 2 ; 1]%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>all_pkeys.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_sync=>ckeys.
    apply r_put_vs_put.
    ssprove_swap_rhs 1%N.
    ssprove_sync=>all_votes.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_sync=>ckeys'.
    set key := (compute_key _ _). clearbody key.
    have Hkey : exists ikey, key = g ^+ ikey.
    { apply /cycleP. rewrite -g_gen. apply in_setT. }
    destruct Hkey as [ikey Hkey].
    rewrite Hkey.
    eapply r_transL.
    { apply r_dead_sample_L.
      1: apply LosslessOp_uniform.
      apply rreflexivity_rule.
    }
    clear all_pkeys all_votes Hdisj1 Hdisj2 rel_i rel_j.
    eapply r_uniform_bij.
    { instantiate (
          1 := λ y,
            (* if (y <= ikey)%N then *)
            (y + (ikey - y))%N).
            (* else *)
            (*   fto (inZp (y + ((q - y) + ikey))%N)). *)
      eexists.
      - intros y.
        case (y <= ikey)%N eqn:e.
        simpl.
        rewrite subnKC.
        + reflexivity.
        + apply e.
    }

    1: shelve.
    intro y_j.
    apply r_put_vs_put.
    ssprove_restore_pre.
      {
        unfold inv, preserve_update_pre.
        unfold remember_pre.
        intros ?? Pre ??.
        apply Pre in H.
        case (ℓ == constructed_keys_loc) eqn:eq; last first.
        - rewrite !get_set_heap_neq.
          + apply H.
          + by apply Bool.negb_true_iff.
          + by apply Bool.negb_true_iff.
        - apply reflection_nonsense in eq.
          rewrite eq.
          rewrite !get_set_heap_eq.
          clear hin Pre H eq rel_i all_votes all_pkeys.
          set key := (compute_key _ _). clearbody key.
          f_equal.
          f_equal.
          have Hkey : exists ikey, key = g ^+ ikey.
          { apply /cycleP. rewrite -g_gen. apply in_setT. }
          destruct Hkey as [ikey Hkey].
          rewrite Hkey.
          rewrite -expgnE.
          have Hs: exists ik, g ^+ ikey = g ^+ (y_j + ik)%N.
          {
            case (y_j <= ikey)%N eqn:e.
            - exists (ikey-y_j)%N.
              simpl.
              rewrite subnKC.
              + reflexivity.
              + apply e.
            - have Hq : (y_j + (q - y_j))%N = q.
              + rewrite subnKC.
                1: reflexivity.
                destruct y_j as [y_j Hy_j].
                simpl in Hy_j.
                simpl.
                clear e.
                unfold q.
                rewrite card_ord Zp_cast in Hy_j.
                {
                  rewrite -ltnS.
                  unfold q in Hy_j.
                  apply leqW, Hy_j.
                }
                apply prime_gt1.
                apply prime_order.
              + exists ((q - y_j) + ikey)%N.
                rewrite addnA.
                rewrite Hq.
                rewrite expgD.
                rewrite expg_order.
                rewrite mul1g.
                reflexivity.
          }
          destruct Hs as [ik Hs].
          rewrite Hs.
          apply /eqP.
          rewrite eq_expg_mod_order.
          assert (Positive i_secret) as i_secret_pos.
          1: apply Secret_pos.
          pose f := λ (x : Arit (uniform #|Sigma1.MyParam.Witness|)), fto (inZp (x + ik)%N) : Arit (uniform i_secret).
          pose f' := f i_secret_pos i_secret_pos.
          Show Existentials.
          instantiate (1 := f').
      }
      Unshelve.
      3: done.
      2: by exists id.
              2: { done. }
              apply r_ret.
      }





    ssprove_swap_seq_lhs [:: 10 ; 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3 ]%N.
    ssprove_swap_seq_rhs [:: 10 ; 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3 ]%N.
    ssprove_swap_seq_lhs [:: 17 ; 16 ; 15 ; 14 ; 13 ; 12 ; 11 ]%N.
    ssprove_swap_seq_rhs [:: 17 ; 16 ; 15 ; 14 ; 13 ; 12 ; 11 ]%N.
    (* ssprove_swap_seq_rhs [:: 27 ; 26 ; 25 ; 24 ; 23 ; 22 ; 21 ; 20 ; 19 ; 18 ; 17 ; 16 ; 15]%N. *)
    (* ssprove_swap_seq_rhs [:: 29 ; 28]%N. *)
    ssprove_swap_seq_rhs [:: 23 ; 22 ; 21]%N.
    ssprove_swap_seq_rhs [:: 25 ; 24 ; 23 ; 22 ; 21 ; 20 ; 19 ; 18 ; 17 ; 16 ; 15 ; 14]%N.
    ssprove_swap_lhs 6%N.
    ssprove_swap_rhs 6%N.
    ssprove_swap_rhs 18%N.
    ssprove_swap_rhs 25%N.
    (* eapply r_uniform_bij. *)
    (* 1: shelve. *)
    (* intros x_i. *)
    ssprove_sync=>x_i.
    apply r_get_remember_lhs=>skeys_lhs.
    apply r_get_remember_rhs=>skeys_rhs.
    ssprove_forget_all.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    eapply r_put_vs_put.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_sync=>rel_i.
    ssprove_sync=>r_i.
    ssprove_sync=>e_i.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    eapply r_put_vs_put.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_sync=>pkeys.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    eapply r_put_vs_put.
    eapply r_uniform_bij.
    1: shelve.
    intros x_j.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_restore_pre.
    1: ssprove_invariant.
    apply r_assertD.
    {
      unfold Sigma1.MyParam.R.
      rewrite !otf_fto !eq_refl.
      reflexivity.
    }
    intros rel_j_lhs rel_j_rhs.
    ssprove_sync=>r_j.
    ssprove_swap_lhs 1%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>e_j.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    ssprove_swap_seq_lhs [:: 3 ; 2 ; 1]%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    apply r_assertD.
    {
      intros [??] _.
      admit.
    }
    intros all_pkeys_lhs all_pkeys_rhs.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_sync=>ckeys.
    ssprove_swap_lhs 0%N.
    ssprove_sync=>all_votes.
    destruct ((setm (T:=[ordType of 'I_#|'I_n|])
              (setm (T:=[ordType of 'I_#|'I_n|]) skeys_rhs i x_i) j x_j j)) eqn:e.
    all: rewrite e ; clear e.
    +
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      ssprove_sync=>ckeys'.
      apply r_put_vs_put.
      ssprove_restore_pre.
      {
        unfold inv, preserve_update_pre.
        unfold remember_pre.
        intros ?? Pre ??.
        apply Pre in H.
        case (ℓ == constructed_keys_loc) eqn:eq; last first.
        - rewrite !get_set_heap_neq.
          + apply H.
          + by apply Bool.negb_true_iff.
          + by apply Bool.negb_true_iff.
        - apply reflection_nonsense in eq.
          rewrite eq.
          rewrite !get_set_heap_eq.
          clear hin Pre H eq rel_i all_votes all_pkeys_lhs all_pkeys_rhs.
          set key := (compute_key _ _).
          f_equal.
          f_equal.
          have Hkey : exists ikey, key = g ^+ ikey.
          { apply /cycleP. rewrite -g_gen. apply in_setT. }
          destruct Hkey as [ikey Hkey].
          rewrite Hkey.
          rewrite -expgnE.
          have Hs: exists ik, g ^+ ikey = g ^+ (s + ik).
          {
            case (s <= ikey)%N eqn:e.
            - exists (ikey-s)%N.
              simpl.
              rewrite subnKC.
              + reflexivity.
              + apply e.
            -
              have Hq : (s + (q - s))%N = q.
              + rewrite subnKC.
                1: reflexivity.
                destruct s as [s Hs].
                simpl in Hs.
                simpl.
                clear e.
                unfold q.
                rewrite card_ord Zp_cast in Hs.
                {
                  rewrite -ltnS.
                  unfold q in Hs.
                  apply leqW, Hs.
                }
                apply prime_gt1.
                apply prime_order.
              + exists ((q - s) + ikey)%N.
                rewrite addnA.
                rewrite Hq.
                rewrite expgD.
                rewrite expg_order.
                rewrite mul1g.
                reflexivity.
          }
          destruct Hs as [ik Hs].
          rewrite Hs.
          symmetry.
          apply /eqP.
          rewrite eq_expg_mod_order.
          apply /eqP.
          have (k' : nat) := val_Zp_nat _ ikey.
          k
      }
    rewrite H.


    ssprove_swap_seq_lhs [:: 10 ; 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3]%N.
    ssprove_swap_seq_rhs [:: 10 ; 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3]%N.
    ssprove_swap_seq_lhs [:: 24 ; 23]%N.
    ssprove_swap_seq_rhs [:: 25 ; 24 ; 23]%N.
    ssprove_swap_seq_lhs [:: 23 ; 22 ; 21 ; 20 ; 19]%N.
    ssprove_swap_seq_rhs [:: 23 ; 22 ; 21 ; 20 ; 19]%N.
    ssprove_swap_seq_lhs [:: 16]%N.
    ssprove_swap_seq_lhs [:: 7]%N.
    ssprove_swap_seq_rhs [:: 16]%N.
    ssprove_swap_seq_rhs [:: 7]%N.
    ssprove_swap_seq_rhs [:: 25 ; 24 ; 23 ; 22 ; 21 ; 20 ; 19 ; 18 ; 17 ; 16 ; 15 ; 14 ; 13 ; 12]%N.




    apply r_const_sample_R.
    1: apply LosslessOp_uniform.
    intro x_i_rhs.
    ssprove_swap_seq_rhs [:: 19 ; 18 ; 17 ; 16 ; 15 ; 14 ; 13 ; 12 ; 11 ; 10 ; 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3 ; 2 ; 1 ; 0]%N.
    ssprove_swap_seq_lhs [:: 10 ; 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3]%N.
    ssprove_swap_seq_rhs [:: 10 ; 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3]%N.
    ssprove_swap_seq_lhs [:: 24 ; 23]%N.
    ssprove_swap_seq_rhs [:: 25 ; 24 ; 23]%N.
    ssprove_swap_seq_lhs [:: 23 ; 22 ; 21 ; 20 ; 19]%N.
    ssprove_swap_seq_rhs [:: 23 ; 22 ; 21 ; 20 ; 19]%N.
    ssprove_swap_seq_lhs [:: 16]%N.
    ssprove_swap_seq_lhs [:: 7]%N.
    ssprove_swap_seq_rhs [:: 16]%N.
    ssprove_swap_seq_rhs [:: 7]%N.
    ssprove_swap_seq_rhs [:: 25 ; 24 ; 23 ; 22 ; 21 ; 20 ; 19 ; 18 ; 17 ; 16 ; 15 ; 14 ; 13 ; 12]%N.
    eapply r_uniform_bij.
    1: shelve.
    intro y_i.
    apply r_get_remember_lhs=>skeys_lhs.
    apply r_get_remember_rhs=>skeys_rhs.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    apply r_assertD.
    {
      intros ??.
      unfold Sigma1.MyParam.R.
      rewrite !otf_fto.
      by rewrite !eq_refl.
    }
    intros rel_i_lhs rel_i_rhs.
    ssprove_sync=>r_i.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>e_i.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_restore_mem.
    1: ssprove_invariant.
    apply r_const_sample_R.
    1: apply LosslessOp_uniform.
    intro x_j_rhs.
    eapply r_uniform_bij.
    1: shelve.
    intro y_j.
    apply r_put_vs_put.
    apply r_assertD.
    {
      intros ??.
      unfold Sigma1.MyParam.R.
      rewrite !otf_fto.
      by rewrite !eq_refl.
    }
    intros rel_j_lhs rel_j_rhs.
    ssprove_sync=>r_j.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>e_j.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_restore_pre.
    1: ssprove_invariant.
    apply r_assertD.
    {
      intros ??.
      unfold Sigma1.MyParam.R.
      rewrite !otf_fto.
      by rewrite !eq_refl.
    }
    ssprove_sync=>all_pkeys.
    ssprove_swap_rhs 0%N.
    ssprove_sync=>ckeys.
    ssprove_swap_seq_lhs [:: 1]%N.
    ssprove_swap_seq_rhs [:: 3 ; 2]%N.
    eapply r_transL.
    { apply r_dead_sample_L.
      1: apply LosslessOp_uniform.
      apply rreflexivity_rule.
    }
    eapply r_uniform_bij.
    1: shelve.
    intros y_i.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>all_votes.
    ssprove_restore_pre.
    {
      unfold inv, preserve_update_pre.
      unfold remember_pre.
      intros ?? Pre ??.
      apply Pre in H.
      case (ℓ == constructed_keys_loc) eqn:eq; last first.
      - rewrite !get_set_heap_neq.
        + apply H.
        + by apply Bool.negb_true_iff.
        + by apply Bool.negb_true_iff.
      - apply reflection_nonsense in eq.
        rewrite eq.
        rewrite !get_set_heap_eq.
        clear hin all_pkeys Pre H eq rel_i rel_j all_votes.
        set key := (compute_key _ _).
        f_equal.
        f_equal.
        have Hkey : exists ikey, key = g ^+ ikey.
        { apply /cycleP. rewrite -g_gen. apply in_setT. }
        destruct Hkey as [ikey Hkey].
        rewrite Hkey.
        rewrite -expgnE.
        symmetry.
        apply /eqP.
        rewrite eq_expg_mod_order.
        apply /eqP.
        have (k' : nat) := val_Zp_nat _ ikey.
        intros.
        rewrite -x.
        2,3: admit.
        Definition f (c : nat) :
          nat -> nat := fun x => c.
        have : (forall c, bijective (f c)).
        {
          intro c.
          unfold f.
          eexists.
          all: intro y.
          - done.
            instantiate (1 := id).

        }
        instantiate (1 := fun y => ikey%:R).
        rewrite -val_Zp_nat.

        simpl.
        eexists.


    }
    eapply r_transL.
    { apply r_dead_sample_L.
      1: apply LosslessOp_uniform.
      apply rreflexivity_rule.
    }
    eapply r_uniform_bij.
    1: shelve.
    intros y_j.
    apply r_put_vs_put.
    ssprove_restore_pre.
    {
      unfold inv, preserve_update_pre.
      unfold remember_pre.
      intros ?? Pre ??.
      apply Pre in H.
      case (ℓ == constructed_keys_loc) eqn:eq; last first.
      - rewrite !get_set_heap_neq.
        + apply H.
        + by apply Bool.negb_true_iff.
        + by apply Bool.negb_true_iff.
        + by apply Bool.negb_true_iff.
        + by apply Bool.negb_true_iff.
      - apply reflection_nonsense in eq.
        rewrite eq.
        rewrite !get_set_heap_eq.
        unfold compute_key.
        f_equal.
        f_equal.
        unfold map_prod.
        simpl.
        set lower := (foldr _ _ _).
        set higher := (foldr _ _ _).
        instantiate
          (1 := λ (x : Arit (uniform i_secret)), x + lower).
        simpl.
      - rewrite Bool.eqb_true_iff in eq.
        rewrite eq_refl in eq.
        erewrite <- get_heap_set_heap.
    }
      ssprove_sync=>all_votes.
      ssprove_sync=>y_j.
      apply r_put_vs_put.
      ssprove_restore_pre.
      {
        Set Typeclasses Debug.
        apply preserve_update_cons_sym_heap_ignore.
        apply preserve_update_r_ignored_heap_ignore.
        a
      }
      apply r_ret.
      intros ?? Inv.
    }

    ssprove_swap_seq_rhs [:: 8 ; 7 ; 6 ; 5 ; 4 ; 3 ; 2 ; 1 ; 0]%N.
    eapply r_transL.
    1: {
      apply r_dead_sample_L.
      1: apply LosslessOp_uniform.
      apply rreflexivity_rule.
    }
    eapply r_uniform_bij.
    2: {
      intros y_i.
      apply r_put_vs_put.
      ssprove_sync=>rel.
      ssprove_sync=>r_j.
      ssprove_swap_lhs 0%N.
      ssprove_swap_rhs 0%N.
      ssprove_sync=>e_j.
      ssprove_contract_put_get_lhs.
      ssprove_contract_put_get_rhs.
      apply r_put_vs_put.
      ssprove_contract_put_get_lhs.
      ssprove_contract_put_get_rhs.
      apply r_put_vs_put.
      ssprove_sync=>all_pkeys.
      ssprove_restore_pre.
      1: ssprove_invariant.
      apply r_get_remember_lhs=>ckeys_lhs.
      apply r_get_remember_rhs=>ckeys_rhs.
      ssprove_swap_seq_lhs [:: 3 ; 2 ; 1]%N.
      ssprove_swap_seq_rhs [:: 3 ; 2 ; 1]%N.
      ssprove_contract_put_get_lhs.
      ssprove_contract_put_get_rhs.
      ssprove_forget_all.
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      ssprove_sync=>pkeys'.
      ssprove_sync=>all_votes.
      ssprove_sync=>y_j.
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      apply r_ret.
      intros ?? Inv ; split.
      - reflexivity.
      - apply Inv.
    }
    Unshelve.
    2: {
      done.
    }
    exists id; done.
  - eapply eq_rel_perf_ind with (inv := inv).
    1,3,5: exact _.
    3,4: assumption.
    1: {
      ssprove_valid.
      5: apply fsubsetxx.
      1: {
        eapply valid_package_inject_export.
        2: eapply valid_package_inject_import.
        3: apply Sigma1.Sigma.Fiat_Shamir.
        - fsubset_auto.
        - fsubset_auto.
      }
      all: unfold combined_locations.
      all: rewrite -!fsetUA.
      - do 2 (apply fsubsetU; apply /orP ; right).
        apply fsubsetUl.
      - do 4 (apply fsubsetU; apply /orP ; right).
        apply fsubsetUl.
      - apply fsetUSS.
        + apply fsubsetxx.
        + apply fsubsetUl.
    }
    simplify_eq_rel ij.
    ssprove_code_simpl.
    rewrite !cast_fun_K.
    destruct ij as [i j].
    ssprove_code_simpl.
    ssprove_code_simpl_more.
    ssprove_code_simpl.
    ssprove_sync=>pkeys.
    ssprove_sync=>xi.
    ssprove_swap_seq_lhs [:: 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3; 2]%N.
    ssprove_swap_seq_rhs [:: 9 ; 8 ; 7 ; 6 ; 5 ; 4 ; 3; 2]%N.
    apply r_get_remember_lhs=>skeys_lhs.
    apply r_get_remember_rhs=>skeys_rhs.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>rel_i.
    ssprove_sync=>r_i.
    ssprove_swap_lhs 0%N.
    ssprove_swap_rhs 0%N.
    ssprove_sync=>e_i.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_restore_mem.
    1: ssprove_invariant.
    ssprove_sync=>x_j.
    apply r_put_vs_put.
    ssprove_sync=>rel_j.
    ssprove_sync=>r_j.
    ssprove_swap_lhs 1%N.
    ssprove_swap_rhs 1%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>e_j.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    apply r_put_vs_put.
    ssprove_sync=>all_pkeys.
    ssprove_restore_pre.
    1: ssprove_invariant.
    apply r_get_remember_lhs=>ckeys_lhs.
    apply r_get_remember_rhs=>ckeys_rhs.
    ssprove_swap_seq_lhs [:: 2 ; 1]%N.
    ssprove_swap_seq_rhs [:: 3 ; 2 ; 1]%N.
    ssprove_contract_put_get_lhs.
    ssprove_contract_put_get_rhs.
    ssprove_forget_all.
    apply r_put_vs_put.
    ssprove_restore_pre.
    1: ssprove_invariant.
    ssprove_sync=>pkeys'.
    ssprove_sync=>all_votes.
    eapply r_transL.
    { apply r_dead_sample_L.
      1: apply LosslessOp_uniform.
      apply rreflexivity_rule. }
    eapply r_uniform_bij.
    2: {
      intro y_j.
      apply r_put_vs_put.
      ssprove_restore_pre.
      1: ssprove_invariant.
      apply r_ret.
      intros ?? Inv ; split.
      - done.
      - done.
    }
    exists id ; done.
  Qed.

  Definition Init_realised := (Init_real ∘ Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO).

  Lemma Init_realised_valid:
    ValidPackage (all_locs :|: (Sigma1.MyAlg.Sigma_locs :|: RO1.RO_locs)) Game_import [interface val #[ INIT ] : 'pid → 'unit] Init_realised.
  Proof.
    unfold Init_realised.
    eapply valid_link.
    1: exact _.
    eapply valid_link.
    2: exact _.
    eapply valid_package_inject_export.
    2: apply Sigma1.Sigma.Fiat_Shamir.
    rewrite !fset_cons.
    rewrite fsetUC.
    apply fsetUSS.
    { rewrite -fset0E. apply fsub0set. }
    rewrite -fset0E fset0U.
    apply fsubsetxx.
  Qed.

  Hint Extern 1 (ValidPackage ?L ?I ?E Init_realised) =>
    apply Init_realised_valid : typeclass_instances ssprove_valid_db.

  Definition Construct_key_realised := (Construct_key_real ∘ Sigma1.Sigma.Fiat_Shamir ∘ RO1.RO).

  Lemma Construct_key_realised_valid:
    ValidPackage (all_locs :|: (Sigma1.MyAlg.Sigma_locs :|: RO1.RO_locs)) Game_import [interface val #[ CONSTRUCT ] : 'pid → 'unit] Construct_key_realised.
  Proof.
    unfold Construct_key_realised.
    eapply valid_link.
    1: exact _.
    eapply valid_link.
    2: exact _.
    eapply valid_package_inject_export.
    2: apply Sigma1.Sigma.Fiat_Shamir.
    rewrite !fset_cons.
    apply fsetUSS.
    { apply fsubsetxx. }
    rewrite -fset0E. apply fsub0set.
  Qed.

  Hint Extern 1 (ValidPackage ?L ?I ?E Construct_key_realised) =>
    apply Construct_key_realised_valid : typeclass_instances ssprove_valid_db.

  Definition Vote_i_realised := (Vote_i_real ∘ Sigma2.Fiat_Shamir ∘ RO2.RO).

  Lemma Vote_i_realised_valid:
    ValidPackage (all_locs :|: (Alg2.Sigma_locs :|: RO2.RO_locs)) Game_import [interface val #[ VOTE_I ] : ('pid × 'bool) → 'unit] Vote_i_realised.
  Proof.
    unfold Vote_i_realised.
    eapply valid_link.
    1: exact _.
    eapply valid_link.
    2: exact _.
    eapply valid_package_inject_export.
    2: apply Sigma2.Fiat_Shamir.
    rewrite !fset_cons.
    rewrite fsetUC.
    apply fsetUSS.
    { rewrite -fset0E. apply fsub0set. }
    rewrite -fset0E fset0U.
    rewrite fset1E.
    apply fsubsetxx.
  Qed.

  Hint Extern 1 (ValidPackage ?L ?I ?E Vote_i_realised) =>
    apply Vote_i_realised_valid : typeclass_instances ssprove_valid_db.

  Definition Vote_i_ideal_realised := (Vote_i_ideal ∘ Sigma2.Fiat_Shamir ∘ RO2.RO).

  Lemma Vote_i_ideal_realised_valid:
    ValidPackage (all_locs :|: (Alg2.Sigma_locs :|: RO2.RO_locs)) Game_import [interface val #[ VOTE_I ] : ('pid × 'bool) → 'unit] Vote_i_ideal_realised.
  Proof.
    unfold Vote_i_realised.
    eapply valid_link.
    1: exact _.
    eapply valid_link.
    2: exact _.
    eapply valid_package_inject_export.
    2: apply Sigma2.Fiat_Shamir.
    rewrite !fset_cons.
    rewrite fsetUC.
    apply fsetUSS.
    { rewrite -fset0E. apply fsub0set. }
    rewrite -fset0E fset0U.
    apply fsubsetxx.
  Qed.

  Definition Sigma2_E :=
    [interface
          val #[ Sigma2.VERIFY ] : chTranscript2 → 'bool ;
          val #[ Sigma2.RUN ] : chRelation2 → chTranscript2
    ].

  Definition Sigma2_locs :=
    (Alg2.Sigma_locs :|: Alg2.Simulator_locs :|: RO2.RO_locs).

  Hint Extern 50 (_ = code_link _ _) =>
    rewrite code_link_scheme
    : ssprove_code_simpl.

  Hint Extern 1 (ValidPackage ?L ?I ?E Vote_i_ideal_realised) =>
    apply Vote_i_ideal_realised_valid : typeclass_instances ssprove_valid_db.

  Lemma sigma_preserves_inv :
    ∀ L0 L1,
    fdisjoint L0 L1 →
    ∀ ℓ : Location,
      ℓ \in L1
            → get_pre_cond ℓ (λ '(s₀, s₁), heap_ignore L0 (s₀, s₁)).
  Proof.
    intros L0 L1 Hdisj l lin.
    apply get_pre_cond_heap_ignore.
    case (l \in L0) eqn:RO.
    + exfalso.
      eapply disjoint_in_both.
      1: apply Hdisj.
      2: apply lin.
      apply RO.
    + done.
  Qed.

  Lemma fdisjoint_left :
    ∀ (T : ordType) (s1 s2 s3 : {fset T}),
      fdisjoint (T:=T) s1 (s2 :|: s3) →
      fdisjoint (T:=T) s1 s2.
  Proof.
    intros T s1 s2 s3 h.
    rewrite fdisjointUr in h.
    apply Bool.andb_true_iff in h.
    destruct h.
    assumption.
  Qed.

  Lemma fdisjoint_right :
    ∀ (T : ordType) (s1 s2 s3 : {fset T}),
      fdisjoint (T:=T) s1 (s2 :|: s3) →
      fdisjoint (T:=T) s1 s3.
  Proof.
    intros T s1 s2 s3.
    rewrite fsetUC.
    apply fdisjoint_left.
  Qed.

  Ltac ssprove_sync_sigma :=
    eapply rsame_head_alt ;
    (try apply prog_valid) ;
    (try (intros ??? ; apply put_pre_cond_heap_ignore)) ;
    (try (eapply sigma_preserves_inv ;
          try (eapply fdisjoint_left ; eassumption) ;
          try (eapply fdisjoint_right ; eassumption))).

  Ltac reduce_valid_par :=
    repeat eapply valid_par_upto ;
    repeat try match goal with
      | [ |- ValidPackage _ _ _ _ ] => exact _
      | [ |- Parable _ _ ] => ssprove_valid
    end.

  Ltac restore_inv :=
    repeat eapply preserve_update_r_ignored_heap_ignore ;
    try apply preserve_update_mem_nil ;
    try unfold RO1.RO_locs, RO2.RO_locs ;
    try rewrite fset_cons -fset0E fsetU0 ;
    try auto_in_fset.

  Notation inv := (heap_ignore (RO1.RO_locs :|: RO2.RO_locs)).
  Instance Invariant_inv : Invariant combined_locations combined_locations inv.
  Proof.
    ssprove_invariant.
    unfold combined_locations.
    apply fsubsetU.
    apply /orP; left.
    apply fsubsetU.
    apply /orP; left.
    rewrite fsubUset.
    apply /andP ; split.
    + apply fsubsetU.
      apply /orP; left.
      rewrite !fsetUA.
      apply fsubsetUr.
    + apply fsubsetU.
      apply /orP; right.
      apply fsubsetU.
      apply /orP; right.
      rewrite !fsetUA.
      apply fsubsetUr.
  Qed.

  Definition OVN_i_I :=
      [interface val #[ INIT ] : 'pid → 'unit ;
                 val #[ CONSTRUCT ] : 'pid → 'unit ;
                 val #[ VOTE_I ] : ('pid × 'bool) → 'unit].

  Definition OVN_i_E :=
      [interface val #[ VOTE ] : ('pid × 'bool) → 'unit].

  Equations? OVN_i_real : package combined_locations [interface] OVN_i_E :=
    OVN_i_real := {package OVN_i ∘ (par Init_realised (par Construct_key_realised Vote_i_realised))}.
  Proof.
    ssprove_valid.
    1-4: apply fsubsetxx.
    - unfold Game_import.
      rewrite -fset0E !fset0U.
      apply fsubsetxx.
    - rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - unfold combined_locations.
      apply fsubsetUr.
    - unfold combined_locations.
      rewrite -!fsetUA.
      repeat apply fsetUS.
      rewrite fsubUset.
      apply /andP ; split.
      + rewrite fsetUC.
        rewrite -fsetUA.
        apply fsubsetUl.
      + apply fsubsetU.
        apply /orP ; right.
        apply fsubsetU.
        apply /orP ; right.
        repeat apply fsetUS.
        apply fsubsetU.
        apply /orP ; right.
        apply fsetUS.
        apply fsetUS.
        apply fsetUS.
        apply fsetUS.
        rewrite fsetUC.
        rewrite -fsetUA.
        apply fsubsetUl.
  Qed.

  Equations? Aux0 : package combined_locations [interface] OVN_i_E :=
    Aux0 := {package OVN_i ∘ (par Init_realised
                                  (par Construct_key_realised
                                       (Vote_i_real ∘ Sigma2.RUN_interactive)))}.
  Proof.
    ssprove_valid.
    1:{ eapply valid_package_inject_export.
        2: eapply valid_package_inject_locations.
        3: apply Sigma2.RUN_interactive.
        + rewrite !fset_cons -fset0E.
          apply fsubsetUr.
        + apply fsubsetxx.
    }
    - instantiate (1 := all_locs :|: Alg2.Sigma_locs).
      apply fsubsetUl.
    - apply fsubsetUr.
    - apply fsubsetxx.
    - apply fsubsetxx.
    - apply fsubsetxx.
    - apply fsubsetxx.
    - unfold Game_import.
      rewrite -fset0E !fsetU0.
      apply fsubsetxx.
    - rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - unfold combined_locations.
      apply fsubsetUr.
    - unfold combined_locations. apply fsubsetU.
      apply /orP ; left.
      apply fsetUSS.
      + apply fsetUS.
        apply fsetSU.
        apply fsubsetUl.
      + apply fsetUSS.
        ++ apply fsetUS.
           apply fsetSU.
           apply fsubsetUl.
        ++ apply fsetUS.
           rewrite -fsetUA.
           apply fsubsetUl.
  Qed.

  Equations? Aux1 : package combined_locations [interface] OVN_i_E :=
    Aux1 := {package OVN_i ∘ (par Init_realised
                                  (par Construct_key_realised
                                       (Vote_i_real ∘ Sigma2.SHVZK_real_aux ∘ Sigma2.SHVZK_real)))}.
  Proof.
    ssprove_valid.
    1-2, 12: apply fsubsetxx.
    1: instantiate (1 := all_locs :|: Alg2.Sigma_locs).
    - apply fsubsetUl.
    - apply fsubsetUr.
    - apply fsubsetxx.
    - apply fsubsetxx.
    - apply fsubsetxx.
    - unfold combined_locations.
      apply fsubsetU.
      apply /orP. left.
      apply fsetUSS.
      + apply fsetUS.
        apply fsetSU.
        apply fsubsetUl.
      + apply fsetUSS.
        ++ apply fsetUS.
           apply fsetSU.
           apply fsubsetUl.
        ++ apply fsetUS.
           rewrite -fsetUA.
           apply fsubsetUl.
    - unfold Game_import.
      rewrite -fset0E !fsetU0.
      apply fsubsetxx.
    - unfold OVN_i_E.
      rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - apply fsubsetUr.
  Qed.

  Equations? Aux2 : package combined_locations [interface] OVN_i_E :=
    Aux2 := {package OVN_i ∘ (par Init_realised
                                  (par Construct_key_realised
                                       (Vote_i_real ∘ Sigma2.SHVZK_real_aux ∘ Sigma2.SHVZK_ideal)))}.
  Proof.
    ssprove_valid.
    1: instantiate (1 := Alg2.Sigma_locs :|: Alg2.Simulator_locs :|: all_locs).
    4,5-7,12: apply fsubsetxx.
    - rewrite -fsetUA ; apply fsubsetUl.
    - rewrite -fsetUA fsetUC -fsetUA. apply fsubsetUl.
    - apply fsubsetUr.
    - unfold combined_locations.
      rewrite -!fsetUA.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      apply fsetUS.
      rewrite fsubUset.
      apply /andP ; split.
      + apply fsubsetU.
        apply /orP ; right.
        apply fsubsetU.
        apply /orP ; right.
        apply fsubsetUl.
      + rewrite fsubUset.
        apply /andP ; split.
        ++ apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetUl.
        ++ apply fsetUS.
           apply fsubsetUl.
    - unfold Game_import.
      rewrite -fset0E !fset0U.
      apply fsub0set.
    - unfold OVN_i_E. rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - unfold combined_locations. apply fsubsetUr.
  Qed.

  Equations? Aux3 : package combined_locations [interface] OVN_i_E :=
    Aux3 := {package OVN_i ∘ (par Init_realised
                                  (par Construct_key_realised
                                       (Vote_i_ideal ∘ Sigma2.SHVZK_real_aux ∘ Sigma2.SHVZK_ideal)))}.
  Proof.
    ssprove_valid.
    1: instantiate (1 := Alg2.Sigma_locs :|: Alg2.Simulator_locs :|: all_locs).
    4,5-7,12: apply fsubsetxx.
    - rewrite -fsetUA ; apply fsubsetUl.
    - rewrite -fsetUA fsetUC -fsetUA. apply fsubsetUl.
    - apply fsubsetUr.
    - unfold combined_locations.
      rewrite -!fsetUA.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      apply fsetUS.
      rewrite fsubUset.
      apply /andP ; split.
      + apply fsubsetU.
        apply /orP ; right.
        apply fsubsetU.
        apply /orP ; right.
        apply fsubsetUl.
      + rewrite fsubUset.
        apply /andP ; split.
        ++ apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetUl.
        ++ apply fsetUS.
           apply fsubsetUl.
    - unfold Game_import.
      rewrite -fset0E !fset0U.
      apply fsub0set.
    - unfold OVN_i_E. rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - unfold combined_locations. apply fsubsetUr.
  Qed.

  Equations? Aux4 : package combined_locations [interface] OVN_i_E :=
    Aux4 := {package OVN_i ∘ (par Init_realised
                                  (par Construct_key_realised
                                       (Vote_i_ideal ∘ Sigma2.SHVZK_real_aux ∘ Sigma2.SHVZK_real)))}.
  Proof.
    ssprove_valid.
    1: instantiate (1 := Alg2.Sigma_locs :|: Alg2.Simulator_locs :|: all_locs).
    4,5-7,12: apply fsubsetxx.
    - rewrite -fsetUA ; apply fsubsetUl.
    - rewrite -fsetUA ; apply fsubsetUl.
    - apply fsubsetUr.
    - unfold combined_locations.
      rewrite -!fsetUA.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      apply fsetUS.
      rewrite fsubUset.
      apply /andP ; split.
      + apply fsubsetU.
        apply /orP ; right.
        apply fsubsetU.
        apply /orP ; right.
        apply fsubsetUl.
      + rewrite fsubUset.
        apply /andP ; split.
        ++ apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetUl.
        ++ apply fsetUS.
           apply fsubsetUl.
    - unfold Game_import.
      rewrite -fset0E !fset0U.
      apply fsub0set.
    - unfold OVN_i_E. rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - unfold combined_locations. apply fsubsetUr.
  Qed.

  Equations? Aux5 : package combined_locations [interface] OVN_i_E :=
    Aux5 := {package OVN_i ∘ (par Init_realised
                                  (par Construct_key_realised
                                       (Vote_i_ideal ∘ Sigma2.RUN_interactive)))}.
  Proof.
    ssprove_valid.
    2: instantiate (1 := Alg2.Sigma_locs :|: Alg2.Simulator_locs :|: all_locs).
    11, 4-6: apply fsubsetxx.
    - ssprove_valid.
      1: eapply valid_package_inject_export.
      2: apply Sigma2.RUN_interactive.
      + rewrite !fset_cons -fset0E.
        apply fsubsetUr.
    - apply fsubsetUr.
    - rewrite -fsetUA. apply fsubsetUl.
    - unfold combined_locations.
      rewrite -!fsetUA.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      apply fsetUS.
      rewrite fsubUset.
      apply /andP ; split.
      + apply fsubsetU.
        apply /orP ; right.
        apply fsubsetU.
        apply /orP ; right.
        apply fsubsetUl.
      + rewrite fsubUset.
        apply /andP ; split.
        ++ apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetU.
           apply /orP ; right.
           apply fsubsetUl.
        ++ apply fsetUS.
           apply fsubsetUl.
    - unfold Game_import.
      rewrite -fset0E !fset0U.
      apply fsub0set.
    - unfold OVN_i_E. rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - apply fsubsetUr.
  Qed.

  Equations? OVN_i_ideal : package combined_locations [interface] OVN_i_E :=
    OVN_i_ideal := {package OVN_i ∘ (par Init_realised
                                         (par Construct_key_realised
                                              Vote_i_ideal_realised))}.
  Proof.
    ssprove_valid.
    1-4: apply fsubsetxx.
    - unfold Game_import.
      rewrite -fset0E !fset0U.
      apply fsub0set.
    - unfold OVN_i_E. rewrite !fset_cons !fset1E -fset0E !fsetU0.
      rewrite fsetSU ; [ done | apply fsubsetxx].
    - apply fsubsetUr.
    - unfold combined_locations.
      rewrite -!fsetUA.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      repeat apply fsetUS.
      apply fsubsetU.
      apply /orP ; right.
      apply fsetUS.
      apply fsetUS.
      apply fsetUS.
      apply fsetUS.
      rewrite fsetUC -fsetUA.
      apply fsubsetUl.
  Qed.


  Theorem OVN_vote_hiding:
    ∀ LA A,
      ValidPackage LA OVN_i_E A_export A →
      fdisjoint LA combined_locations →
      fdisjoint (RO1.RO_locs :|: RO2.RO_locs) (Alg1.Sigma_locs :|: Alg1.Simulator_locs) →
      fdisjoint (RO1.RO_locs :|: RO2.RO_locs) (Alg2.Sigma_locs :|: Alg2.Simulator_locs) →
      AdvantageE OVN_i_real OVN_i_ideal A <=
          Sigma2.ɛ_SHVZK (((A ∘ par (par Construct_key_realised Vote_i_realised)
                                (ID [interface val #[INIT] : 'pid → 'unit ])) ∘ Init_real)
                              ∘ Sigma2.SHVZK_real_aux)
          + Sigma2.ɛ_SHVZK (((A ∘ par (par Construct_key_realised Vote_i_ideal_realised)
                                            (ID [interface val #[INIT] : 'pid → 'unit ])) ∘ Init_real)
                                ∘ Sigma2.SHVZK_real_aux).
  Proof.
    intros LA A Va Hdisj Hdisj_RO1 Hdisj_RO2.
    unfold Init_realised.
    ssprove triangle OVN_i_real [::
      (Aux0).(pack) ;
      (Aux1).(pack) ;
      (Aux2).(pack) ;
      (Aux3).(pack) ;
      (Aux5).(pack)
    ] OVN_i_ideal A as ineq.
    eapply ler_trans. 1: exact: ineq.
    clear ineq.
    apply ler_naddr.
    1:{
      eapply eq_ler.
      eapply eq_rel_perf_ind with (inv := inv).
      6,7: apply Hdisj.
      1-3,5: exact _.
      simplify_eq_rel h.
      ssprove_code_simpl.
      destruct h as [h w].
      rewrite ?cast_fun_K ; ssprove_code_simpl.
      ssprove_code_simpl_more ; ssprove_code_simpl.
      ssprove_sync=>r.
      ssprove_sync=>sk.
      ssprove_sync=>?.
      ssprove_sync=>rel.
      ssprove_sync_sigma=>a.
      ssprove_contract_put_get_rhs.
      ssprove_contract_put_get_lhs.
      eapply r_put_vs_put.
      rewrite emptymE.
      ssprove_sync=>e.
      eapply r_put_vs_put.
      ssprove_restore_pre.
      { restore_inv.
        restore_inv.
      }
      ssprove_sync_sigma=>z.
        ssprove_sync=>pks.
        ssprove_sync=>?.
        eapply r_ret.
        split ; done.
      - ssprove_sync=>pks.
        ssprove_sync=>cks.
        ssprove_sync=>?.
        eapply r_ret.
        split ; done.
      - destruct h as [h w].
        ssprove_sync=>cks.
        ssprove_sync=>pks.
        destruct (cks h) eqn:eqcks.
        all: rewrite eqcks.
        2: ssprove_sync=>? ; apply r_ret; split ; done.
        simpl.
        destruct (pks h) eqn:eqpks.
        all: rewrite eqpks.
        2: ssprove_sync=>? ; apply r_ret; split ; done.
        ssprove_code_simpl_more.
        ssprove_code_simpl.
        ssprove_sync=>rel.
        ssprove_sync_sigma=>a.
        ssprove_contract_put_get_lhs.
        ssprove_contract_put_get_rhs.
        eapply r_put_vs_put.
        rewrite emptymE.
        ssprove_sync=>e.
        eapply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        ssprove_sync_sigma=>z.
        ssprove_sync=>votes.
        eapply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        apply r_ret ; split ; done.
    }
    apply ler_naddr.
    1:{
      eapply eq_ler.
      eapply eq_rel_perf_ind with (inv := inv).
      6,7: apply Hdisj.
      1-3,5: exact _.
      simplify_eq_rel h.
      all: ssprove_code_simpl.
      all: rewrite ?cast_fun_K ; ssprove_code_simpl.
      all: ssprove_code_simpl_more ; ssprove_code_simpl.
      - ssprove_sync=>r.
        ssprove_sync=>sks.
        ssprove_sync=>?.
        ssprove_swap_lhs 0%N.
        ssprove_sync=>rel.
        ssprove_swap_lhs 0%N.
        ssprove_sync_sigma=>a.
        ssprove_sync=>e.
        ssprove_sync_sigma=>z.
        ssprove_sync=>pks.
        ssprove_sync=>?.
        apply r_ret ; split ; done.
      - ssprove_sync=>pks.
        ssprove_sync=>cks.
        ssprove_sync=>?.
        eapply r_ret.
        split ; done.
      - destruct h as [h w].
        ssprove_sync=>cks.
        ssprove_sync=>pks.
        destruct (cks h) eqn:eqcks.
        all: rewrite eqcks.
        2: ssprove_sync=>? ; apply r_ret; split ; done.
        simpl.
        destruct (pks h) eqn:eqpks.
        all: rewrite eqpks.
        2: ssprove_sync=>? ; apply r_ret; split ; done.
        ssprove_code_simpl_more.
        ssprove_code_simpl.
        ssprove_sync=>rel.
        ssprove_sync_sigma=>a.
        ssprove_contract_put_get_lhs.
        ssprove_contract_put_get_rhs.
        eapply r_put_vs_put.
        rewrite emptymE.
        ssprove_sync=>e.
        eapply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        ssprove_sync_sigma=>z.
        ssprove_sync=>votes.
        eapply r_put_vs_put.
        ssprove_restore_pre.
        1: ssprove_invariant.
        apply r_ret ; split ; done.
    }
    apply ler_add.
    2:{ unfold Aux3, Aux5, pack.
        rewrite par_commut.
        rewrite Advantage_sym.
        rewrite par_commut.
        erewrite Advantage_par.
        - unfold Sigma1.ɛ_SHVZK.
          rewrite -Advantage_link.
          rewrite -Advantage_link.
          done.
        - ssprove_valid.
          1,3: apply fsubsetxx.
          unfold Game_import.
          rewrite -fset0E fset0U.
          apply fsub0set.
        - ssprove_valid.
          4,5: apply fsubsetxx.
          + apply Init_real.
          + apply Sigma1.SHVZK_real_aux.
          + apply Sigma1.SHVZK_real.
          + instantiate (1 := all_locs :|: Alg1.Sigma_locs) ; apply fsubsetUl.
          + apply fsubsetUr.
        - ssprove_valid.
          + apply Init_real.
          + apply Sigma1.SHVZK_real_aux.
          + apply Sigma1.SHVZK_ideal.
          + instantiate (1 := Alg1.Simulator_locs :|: Alg1.Sigma_locs) ; apply fsubsetUr.
          + apply fsubsetUl.
          + apply fsubsetUl.
          + apply fsubsetUr.
        - ssprove_valid.
        - apply trimmed_package_par.
          1: ssprove_valid.
          + unfold Construct_key_realised, trimmed.
            rewrite -link_trim_commut.
            f_equal.
            apply trimmed_package_cons, trimmed_empty_package.
          + unfold Vote_i_ideal_realised, trimmed.
            rewrite -link_trim_commut.
            f_equal.
            apply trimmed_package_cons, trimmed_empty_package.
        - unfold trimmed.
          rewrite -link_trim_commut.
          f_equal.
          apply trimmed_package_cons, trimmed_empty_package.
        - unfold trimmed.
          rewrite -link_trim_commut.
          f_equal.
          apply trimmed_package_cons, trimmed_empty_package.
    }
    apply ler_naddr.
    1: {
      eapply eq_ler.
      eapply eq_rel_perf_ind with (inv := inv).
      6,7: apply Hdisj.
      1-3,5: exact _.
      simplify_eq_rel h.
      all: ssprove_code_simpl.
      all: rewrite ?cast_fun_K ; ssprove_code_simpl.
      all: ssprove_code_simpl_more ; ssprove_code_simpl.
      - ssprove_sync=>r.
        ssprove_sync=>sks.
        ssprove_sync=>?.
        ssprove_sync=>e.
        ssprove_sync=>rel.
        ssprove_sync_sigma=>a.
        ssprove_sync=>pks.
        ssprove_sync=>_.
        apply r_ret ; split ; done.
      - ssprove_sync=>pks.
        ssprove_sync=>cks.
        ssprove_sync=>?.
        eapply r_ret.
        split ; done.
      - destruct h as [h w].
        ssprove_sync=>cks.
        ssprove_sync=>pks.
        destruct (cks h) eqn:eqcks.
        all: rewrite eqcks.
        2: ssprove_sync=>? ; apply r_ret; split ; done.
        simpl.
        destruct (pks h) eqn:eqpks.
        all: rewrite eqpks.
        2: ssprove_sync=>? ; apply r_ret; split ; done.
        ssprove_code_simpl_more.
        ssprove_code_simpl.
        eapply r_assertD.
        {
          intros [h0 h1] ?.
          destruct w.
          all: simpl ; unfold pack_statement2 ; rewrite !otf_fto .
          all: rewrite π2.relation_valid_left π2.relation_valid_right ; reflexivity.
        }
        intros rel_left rel_right.
        ssprove_sync_sigma.
    apply ler_naddl.
    2:{ rewrite par_commut.
        rewrite Advantage_sym.
        rewrite par_commut.
        rewrite Advantage_sym.
        erewrite Advantage_par.
        - unfold Sigma1.ɛ_SHVZK.
          rewrite -Advantage_link.
          rewrite -Advantage_link.
          done.
        - ssprove_valid.
          1: apply fsubsetxx.
          { unfold Game_import. rewrite -fset0E fset0U. apply fsubsetxx. }
          apply fsubsetxx.
        - repeat apply valid_link ; exact _.
        - eapply valid_link.
          2: eapply valid_link ; exact _.
          exact _.
        - ssprove_valid.
        - apply trimmed_package_par.
          1: ssprove_valid.
          + unfold Construct_key_realised, trimmed.
            rewrite -link_trim_commut.
            f_equal.
            apply trimmed_package_cons, trimmed_empty_package.
          + unfold Vote_i_realised, trimmed.
            rewrite -link_trim_commut.
            f_equal.
            apply trimmed_package_cons, trimmed_empty_package.
        - unfold trimmed.
          rewrite -link_trim_commut.
          f_equal.
          apply trimmed_package_cons, trimmed_empty_package.
        - unfold trimmed.
          rewrite -link_trim_commut.
          f_equal.
          apply trimmed_package_cons, trimmed_empty_package.
    }
    apply ler_naddr.
    1:{ apply eq_ler.
        eapply eq_rel_perf_ind with (inv := inv).
        6,7: apply Hdisj.
        3,5: exact _.
        2: apply Aux1.
        1: apply Aux0.
        simplify_eq_rel h.
        all: ssprove_code_simpl.
        all: rewrite ?cast_fun_K ; ssprove_code_simpl.
        all: ssprove_code_simpl_more ; ssprove_code_simpl.
        - ssprove_sync=>x.
          ssprove_sync=>sk.
          ssprove_sync=>?.
          ssprove_swap_rhs 0%N.
          ssprove_sync=>rel.
          ssprove_swap_rhs 0%N.
          { eapply rsamplerC. }
          ssprove_sync_sigma=>a.
          ssprove_sync=>e.
          ssprove_sync_sigma=>z.
          ssprove_sync=>pk.
          ssprove_sync=>_.
          apply r_ret.
          split ; done.
        - ssprove_sync=>pk.
          ssprove_sync=>key.
          ssprove_sync=>?.
          apply r_ret.
          split ; done.
        - destruct h.
          ssprove_sync=>key.
          ssprove_sync=>sk.
          destruct (key s) eqn:keyeq.
          all: rewrite keyeq.
          2:{ ssprove_sync=>?.
              apply r_ret.
              split ; done.
          }
          simpl.
          destruct (sk s) eqn:skeq.
          all: rewrite skeq.
          2:{ ssprove_sync=>?.
              apply r_ret.
              split ; done.
          }
          ssprove_code_simpl_more.
          ssprove_code_simpl.
          ssprove_sync=>rel.
          ssprove_sync_sigma=>a.
          ssprove_contract_put_get_lhs.
          ssprove_contract_put_get_rhs.
          ssprove_sync=>?.
          rewrite emptymE.
          ssprove_sync=>e.
          ssprove_sync=>_.
          ssprove_sync_sigma=>z.
          ssprove_sync=>votes.
          ssprove_sync=>_.
          apply r_ret.
          split ; done.
    }
    apply eq_ler.
    eapply eq_rel_perf_ind with (inv := inv).
    6,7: apply Hdisj.
    3,5: exact _.
    2: apply Aux0.
    1: exact _.
    simplify_eq_rel h.
    + ssprove_code_simpl.
      rewrite !cast_fun_K.
      ssprove_code_simpl.
      ssprove_code_simpl_more.
      ssprove_code_simpl.
      ssprove_sync=>x.
      ssprove_sync=>sk.
      ssprove_sync=>?.
      ssprove_sync=>rel.
      ssprove_sync_sigma=>a.
      ssprove_contract_put_get_lhs.
      rewrite emptymE.
      apply r_put_lhs.
      ssprove_sync=>e.
      apply r_put_lhs.
      ssprove_restore_pre.
      { ssprove_invariant.
        repeat eapply preserve_update_l_ignored_heap_ignore.
        3: apply preserve_update_mem_nil.
        all: unfold RO1.RO_locs, RO2.RO_locs.
        + rewrite fset_cons -fset0E fsetU0. auto_in_fset.
        + rewrite fset_cons -fset0E fsetU0. auto_in_fset.
      }
      ssprove_sync_sigma=>z.
      ssprove_sync=>?.
      ssprove_sync=>?.
      eapply r_ret.
      split; done.
    + ssprove_sync=>x.
      ssprove_sync=>key.
      ssprove_sync=>?.
      apply r_ret.
      move=> s0 s1 H.
      split ; done.
    + ssprove_code_simpl.
      destruct h as [h w].
      rewrite !cast_fun_K.
      ssprove_code_simpl.
      ssprove_sync=>key.
      ssprove_sync=>sk.
      destruct (key h) eqn:eq_key.
      all: rewrite eq_key.
      2: { ssprove_sync=>x.
          apply r_ret.
          move=> s0 s1 H.
          split; done.
      }
      simpl.
      destruct (sk h) eqn:eq_sk.
      all: rewrite eq_sk.
      2:{ ssprove_sync=>x.
          apply r_ret.
          move=> s0 s1 H.
          split ; done.
      }
      ssprove_code_simpl_more.
      ssprove_code_simpl.
      ssprove_sync=>rel.
      ssprove_sync_sigma=>a.
      ssprove_contract_put_get_lhs.
      ssprove_contract_put_get_rhs.
      ssprove_sync=>?.
      rewrite emptymE.
      ssprove_sync=>e.
      ssprove_sync=>_.
      ssprove_sync_sigma=>z.
      ssprove_sync=>votes.
      ssprove_sync=>_.
      apply r_ret.
      split ; done.
  Qed.
