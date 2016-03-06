(** Formal Reasoning About Programs <http://adam.chlipala.net/frap/>
  * Chapter 7: Abstract Interpretation and Dataflow Analysis
  * Author: Adam Chlipala
  * License: https://creativecommons.org/licenses/by-nc-nd/4.0/ *)

Require Import Frap Imp.

Set Implicit Arguments.


Module SimpleAbstractInterpreter.
  Record absint := {
    Typeof :> Set;
    (* This [:>] notation lets us treat any [absint] as its [Typeof],
     * automatically. *)
    Top : Typeof;
    (* A lattice element that describes all concrete values *)
    Constant : nat -> Typeof;
    (* Most accurate representation of a constant *)
    Add : Typeof -> Typeof -> Typeof;
    Subtract : Typeof -> Typeof -> Typeof;
    Multiply : Typeof -> Typeof -> Typeof;
    (* Abstract versions of arithmetic operators *)
    Join : Typeof -> Typeof -> Typeof;
    (* Least upper bound of two elements *)
    Represents : nat -> Typeof -> Prop
    (* Which lattice elements represent which numbers? *)
  }.

  Record absint_sound (a : absint) : Prop := {
    TopSound : forall n, a.(Represents) n a.(Top);
    
    ConstSound : forall n, a.(Represents) n (a.(Constant) n);

    AddSound : forall n na m ma, a.(Represents) n na
                                 -> a.(Represents) m ma
                                 -> a.(Represents) (n + m) (a.(Add) na ma);
    SubtractSound: forall n na m ma, a.(Represents) n na
                                     -> a.(Represents) m ma
                                     -> a.(Represents) (n - m) (a.(Subtract) na ma);
    MultiplySound : forall n na m ma, a.(Represents) n na
                                      -> a.(Represents) m ma
                                      -> a.(Represents) (n * m) (a.(Multiply) na ma);

    AddMonotone : forall na na' ma ma', (forall n, a.(Represents) n na -> a.(Represents) n na')
                                        -> (forall n, a.(Represents) n ma -> a.(Represents) n ma')
                                        -> (forall n, a.(Represents) n (a.(Add) na ma)
                                                      -> a.(Represents) n (a.(Add) na' ma'));
    SubtractMonotone : forall na na' ma ma', (forall n, a.(Represents) n na -> a.(Represents) n na')
                                             -> (forall n, a.(Represents) n ma -> a.(Represents) n ma')
                                             -> (forall n, a.(Represents) n (a.(Subtract) na ma)
                                                           -> a.(Represents) n (a.(Subtract) na' ma'));
    MultiplyMonotone : forall na na' ma ma', (forall n, a.(Represents) n na -> a.(Represents) n na')
                                             -> (forall n, a.(Represents) n ma -> a.(Represents) n ma')
                                             -> (forall n, a.(Represents) n (a.(Multiply) na ma)
                                                           -> a.(Represents) n (a.(Multiply) na' ma'));

    JoinSoundLeft : forall x y n, a.(Represents) n x
                                  -> a.(Represents) n (a.(Join) x y);
    JoinSoundRight : forall x y n, a.(Represents) n y
                                   -> a.(Represents) n (a.(Join) x y)
  }.

  Definition absint_complete (a : absint) :=
    forall x y z n, a.(Represents) n (a.(Join) x y)
                    -> (forall n, a.(Represents) n x -> a.(Represents) n z)
                    -> (forall n, a.(Represents) n y -> a.(Represents) n z)
                    -> a.(Represents) n z.

  Hint Resolve TopSound ConstSound AddSound SubtractSound MultiplySound
       AddMonotone SubtractMonotone MultiplyMonotone
       JoinSoundLeft JoinSoundRight.


  (** * Example: even-odd analysis *)

  Inductive parity := Even | Odd | Either.

  Definition isEven (n : nat) := exists k, n = k * 2.
  Definition isOdd (n : nat) := exists k, n = k * 2 + 1.

  Theorem decide_parity : forall n, isEven n \/ isOdd n.
  Proof.
    induct n; simplify; propositional.

    left; exists 0; linear_arithmetic.

    invert H.
    right.
    exists x; linear_arithmetic.

    invert H.
    left.
    exists (x + 1); linear_arithmetic.
  Qed.

  Theorem notEven_odd : forall n, ~isEven n -> isOdd n.
  Proof.
    simplify.
    assert (isEven n \/ isOdd n).
    apply decide_parity.
    propositional.
  Qed.

  Theorem odd_notEven : forall n, isOdd n -> ~isEven n.
  Proof.
    propositional.
    invert H.
    invert H0.
    linear_arithmetic.
  Qed.

  Theorem isEven_0 : isEven 0.
  Proof.
    exists 0; linear_arithmetic.
  Qed.

  Theorem isEven_1 : ~isEven 1.
  Proof.
    propositional; invert H; linear_arithmetic.
  Qed.

  Theorem isEven_S_Even : forall n, isEven n -> ~isEven (S n).
  Proof.
    propositional; invert H; invert H0; linear_arithmetic.
  Qed.

  Theorem isEven_S_Odd : forall n, ~isEven n -> isEven (S n).
  Proof.
    propositional.
    apply notEven_odd in H.
    invert H.
    exists (x + 1); linear_arithmetic.
  Qed.

  Hint Resolve isEven_0 isEven_1 isEven_S_Even isEven_S_Odd.  

  Definition parity_flip (p : parity) :=
    match p with
    | Even => Odd
    | Odd => Even
    | Either => Either
    end.

  Fixpoint parity_const (n : nat) :=
    match n with
    | O => Even
    | S n' => parity_flip (parity_const n')
    end.

  Definition parity_add (x y : parity) :=
    match x, y with
    | Even, Even => Even
    | Odd, Odd => Even
    | Even, Odd => Odd
    | Odd, Even => Odd
    | _, _ => Either
    end.

  Definition parity_subtract (x y : parity) :=
    match x, y with
    | Even, Even => Even
    | _, _ => Either
    end.
  (* Note subtleties with [Either]s above, to deal with underflow at zero! *)

  Definition parity_multiply (x y : parity) :=
    match x, y with
    | Even, _ => Even
    | Odd, Odd => Odd
    | _, Even => Even
    | _, _ => Either
    end.

  Definition parity_join (x y : parity) :=
    match x, y with
    | Even, Even => Even
    | Odd, Odd => Odd
    | _, _ => Either
    end.

  Inductive parity_rep : nat -> parity -> Prop :=
  | PrEven : forall n,
    isEven n
    -> parity_rep n Even
  | PrOdd : forall n,
    ~isEven n
    -> parity_rep n Odd
  | PrEither : forall n,
    parity_rep n Either.

  Hint Constructors parity_rep.

  Definition parity_absint := {|
    Top := Either;
    Constant := parity_const;
    Add := parity_add;
    Subtract := parity_subtract;
    Multiply := parity_multiply;
    Join := parity_join;
    Represents := parity_rep
  |}.

  Lemma parity_const_sound : forall n,
    parity_rep n (parity_const n).
  Proof.
    induct n; simplify; eauto.
    cases (parity_const n); simplify; eauto.
    invert IHn; eauto.
    invert IHn; eauto.
  Qed.

  Hint Resolve parity_const_sound.

  Lemma even_not_odd :
    (forall n, parity_rep n Even -> parity_rep n Odd)
    -> False.
  Proof.
    simplify.
    specialize (H 0).
    assert (parity_rep 0 Even) by eauto.
    apply H in H0.
    invert H0.
    apply H1.
    auto.
  Qed.

  Lemma odd_not_even :
    (forall n, parity_rep n Odd -> parity_rep n Even)
    -> False.
  Proof.
    simplify.
    specialize (H 1).
    assert (parity_rep 1 Odd) by eauto.
    apply H in H0.
    invert H0.
    invert H1.
    linear_arithmetic.
  Qed.

  Hint Resolve even_not_odd odd_not_even.

  Lemma parity_join_complete : forall n x y,
    parity_rep n (parity_join x y)
    -> parity_rep n x \/ parity_rep n y.
  Proof.
    simplify; cases x; cases y; simplify; propositional.
    assert (isEven n \/ isOdd n) by apply decide_parity.
    propositional; eauto using odd_notEven.
    assert (isEven n \/ isOdd n) by apply decide_parity.
    propositional; eauto using odd_notEven.
  Qed.

  Hint Resolve parity_join_complete.

  Theorem parity_sound : absint_sound parity_absint.
  Proof.
    constructor; simplify; eauto;
    repeat match goal with
           | [ H : parity_rep _ _ |- _ ] => invert H
           | [ H : ~isEven _ |- _ ] => apply notEven_odd in H; invert H
           | [ H : isEven _ |- _ ] => invert H
           | [ p : parity |- _ ] => cases p; simplify; try equality
           end; try solve [ exfalso; eauto ]; try (constructor; try apply odd_notEven).
    exists (x0 + x); ring.
    exists (x0 + x); ring.
    exists (x0 + x); ring.
    exists (x0 + x + 1); ring.
    exists (x - x0); linear_arithmetic.
    exists (x * x0 * 2); ring.
    exists ((x * 2 + 1) * x0); ring.
    exists (n * x); ring.
    exists ((x * 2 + 1) * x0); ring.
    exists (2 * x * x0 + x + x0); ring.
    exists (x * m); ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x; ring.
    exists x0; ring.
    exists x0; ring.
  Qed.

  Theorem parity_complete : absint_complete parity_absint.
  Proof.
    unfold absint_complete; simplify; eauto;
    repeat match goal with
           | [ H : parity_rep _ _ |- _ ] => invert H
           | [ H : ~isEven _ |- _ ] => apply notEven_odd in H; invert H
           | [ H : isEven _ |- _ ] => invert H
           | [ p : parity |- _ ] => cases p; simplify; try equality
           end; try solve [ exfalso; eauto ]; try (constructor; try apply odd_notEven).
    exists x0; ring.
    exists x0; ring.
  Qed.


  (** * Flow-insensitive analysis *)

  Definition astate (a : absint) := fmap var a.

  Fixpoint absint_interp (e : arith) a (s : astate a) : a :=
    match e with
    | Const n => a.(Constant) n
    | Var x => match s $? x with
               | None => a.(Top)
               | Some xa => xa
               end
    | Plus e1 e2 => a.(Add) (absint_interp e1 s) (absint_interp e2 s)
    | Minus e1 e2 => a.(Subtract) (absint_interp e1 s) (absint_interp e2 s)
    | Times e1 e2 => a.(Multiply) (absint_interp e1 s) (absint_interp e2 s)
    end.

  Fixpoint assignmentsOf (c : cmd) : set (var * arith) :=
    match c with
    | Skip => {}
    | Assign x e => {(x, e)}
    | Sequence c1 c2 => assignmentsOf c1 \cup assignmentsOf c2
    | If _ c1 c2 => assignmentsOf c1 \cup assignmentsOf c2
    | While _ c1 => assignmentsOf c1
    end.

  Theorem assignmentsOf_ok : forall v c v' c',
    step (v, c) (v', c')
    -> v' = v \/ exists x e, (x, e) \in assignmentsOf c
                          /\ v' = v $+ (x, interp e v).
  Proof.
    induct 1; unfold Sets.In; simplify; eauto 10.
    first_order.
  Qed.

  Theorem assignmentsOf_monotone : forall v c v' c',
    step (v, c) (v', c')
    -> assignmentsOf c' \subseteq assignmentsOf c.
  Proof.
    induct 1; simplify; sets.
    (* [sets]: simplify a goal involving set-theory operators. *)
  Qed.

  Definition merge_astate a : astate a -> astate a -> astate a :=
    merge (fun x y =>
             match x with
             | None => None
             | Some x' =>
               match y with
               | None => None
               | Some y' => Some (a.(Join) x' y')
               end
             end).

  Inductive flow_insensitive_step a (c : cmd) : astate a -> astate a -> Prop :=
  | InsensitiveNothing : forall s,
    flow_insensitive_step c s s
  | InsensitiveStep : forall x e s,
    (x, e) \in assignmentsOf c
    -> flow_insensitive_step c s (merge_astate s (s $+ (x, absint_interp e s))).

  Hint Constructors flow_insensitive_step.

  Definition flow_insensitive_trsys a (s : astate a) (c : cmd) := {|
    Initial := {s};
    Step := flow_insensitive_step (a := a) c
  |}.

  Definition insensitive_compatible a (s : astate a) (v : valuation) : Prop :=
    forall x xa, s $? x = Some xa
                 -> (exists n, v $? x = Some n
                               /\ a.(Represents) n xa)
                    \/ (forall n, a.(Represents) n xa).

  Inductive Rinsensitive a (c : cmd) : valuation * cmd -> astate a -> Prop :=
  | RInsensitive : forall v s c',
    insensitive_compatible s v
    -> assignmentsOf c' \subseteq assignmentsOf c
    -> Rinsensitive c (v, c') s.

  Hint Constructors Rinsensitive.

  Lemma insensitive_compatible_add : forall a (s : astate a) v x na n,
    insensitive_compatible s v
    -> a.(Represents) n na
    -> insensitive_compatible (s $+ (x, na)) (v $+ (x, n)).
  Proof.
    unfold insensitive_compatible; simplify.
    cases (x ==v x0); simplify; eauto.
    invert H1; eauto.
  Qed.

  Theorem absint_interp_ok : forall a, absint_sound a
    -> forall (s : astate a) v e,
      insensitive_compatible s v
      -> a.(Represents) (interp e v) (absint_interp e s).
  Proof.
    induct e; simplify; eauto.
    cases (s $? x); auto.
    unfold insensitive_compatible in H0.
    apply H0 in Heq.
    invert Heq.
    invert H1.
    propositional.
    rewrite H1.
    assumption.
    eauto.
  Qed.

  Hint Resolve insensitive_compatible_add absint_interp_ok.

  Theorem insensitive_simulates : forall a (s : astate a) v c,
    absint_sound a
    -> insensitive_compatible s v
    -> simulates (Rinsensitive (a := a) c) (trsys_of v c) (flow_insensitive_trsys s c).
  Proof.
    simplify.
    constructor; simplify.

    exists s; propositional.
    subst.
    constructor.
    assumption.
    sets.

    invert H1.
    cases st1'.
    assert (assignmentsOf c0 \subseteq assignmentsOf c).
    apply assignmentsOf_monotone in H2.
    sets.
    apply assignmentsOf_ok in H2.
    propositional; subst.
    eauto.
    invert H5.
    invert H2.
    propositional; subst.
    exists (merge_astate st2 (st2 $+ (x, absint_interp x0 st2))).
    propositional; eauto.
    econstructor; eauto.
    unfold insensitive_compatible in *; simplify.
    unfold merge_astate in *; simplify.
    cases (st2 $? x1); simplify; try equality.
    cases (x ==v x1); simplify; try equality.
    invert H5; eauto 6.
    rewrite Heq in H5.
    invert H5; eauto.
    apply H3 in Heq; propositional; eauto.
    invert H5; propositional; eauto.
  Qed.

  Inductive runAllAssignments a : set (var * arith) -> astate a -> astate a -> Prop :=
  | RunDone : forall s,
    runAllAssignments {} s s
  | RunStep : forall x e xes s s',
    runAllAssignments (constant xes) (merge_astate s (s $+ (x, absint_interp e s))) s'
    -> runAllAssignments (constant ((x, e) :: xes)) s s'.

  Inductive iterate a (c : cmd) : astate a -> astate a -> Prop :=
  | IterateDone : forall s,
    runAllAssignments (assignmentsOf c) s s
    -> iterate c s s
  | IterateStep : forall s s' s'',
    runAllAssignments (assignmentsOf c) s s'
    -> iterate c s' s''
    -> iterate c s s''.

  Definition subsumed a (s1 s2 : astate a) :=
    forall x, match s1 $? x with
              | None => s2 $? x = None
              | Some xa1 =>
                forall xa2, s2 $? x = Some xa2
                            -> forall n, a.(Represents) n xa1
                                         -> a.(Represents) n xa2
              end.

  Theorem subsumed_refl : forall a (s : astate a),
    subsumed s s.
  Proof.
    unfold subsumed; simplify.
    cases (s $? x); equality.
  Qed.

  Hint Resolve subsumed_refl.

  Lemma subsumed_use : forall a (s s' : astate a) x n t0 t,
    s $? x = Some t0
    -> subsumed s s'
    -> s' $? x = Some t
    -> Represents a n t0
    -> Represents a n t.
  Proof.
    unfold subsumed; simplify.
    specialize (H0 x).
    rewrite H in H0.
    eauto.
  Qed.

  Lemma subsumed_use_empty : forall a (s s' : astate a) x n t0 t,
    s $? x = None
    -> subsumed s s'
    -> s' $? x = Some t
    -> Represents a n t0
    -> Represents a n t.
  Proof.
    unfold subsumed; simplify.
    specialize (H0 x).
    rewrite H in H0.
    equality.
  Qed.

  Hint Resolve subsumed_use subsumed_use_empty.

  Lemma absint_interp_monotone : forall a, absint_sound a
    -> forall (s : astate a) e s' n,
      a.(Represents) n (absint_interp e s)
      -> subsumed s s'
      -> a.(Represents) n (absint_interp e s').
  Proof.
    induct e; simplify; eauto.

    cases (s' $? x); eauto.
    cases (s $? x); eauto.
  Qed.

  Hint Resolve absint_interp_monotone.

  Lemma subsumed_trans : forall a (s1 s2 s3 : astate a),
    subsumed s1 s2
    -> subsumed s2 s3
    -> subsumed s1 s3.
  Proof.
    unfold subsumed; simplify.
    specialize (H x); specialize (H0 x).
    cases (s1 $? x); simplify.
    cases (s2 $? x); eauto.
    cases (s2 $? x); eauto.
    equality.
  Qed.

  Lemma subsumed_merge_left : forall a, absint_sound a
    -> forall s1 s2 : astate a,
      subsumed s1 (merge_astate s1 s2).
  Proof.
    unfold subsumed, merge_astate; simplify.
    cases (s1 $? x); trivial.
    cases (s2 $? x); simplify; try equality.
    invert H0; eauto.
  Qed.

  Hint Resolve subsumed_merge_left.

  Lemma runAllAssignments_monotone : forall a, absint_sound a
    -> forall xes (s s' : astate a),
      runAllAssignments xes s s'
      -> subsumed s s'.
  Proof.
    induct 2; simplify; eauto using subsumed_trans.
  Qed.    

  Hint Resolve runAllAssignments_monotone.

  Lemma runAllAssignments_ok : forall a, absint_sound a
    -> forall xes (s s' : astate a),
      runAllAssignments xes s s'
      -> forall x e, (x, e) \in xes
                  -> subsumed (s $+ (x, absint_interp e s)) s'.
  Proof.
    induct 2; unfold Sets.In; simplify; propositional.

    invert H2.
    apply subsumed_trans with (s2 := merge_astate s (s $+ (x0, absint_interp e0 s))); eauto.
    unfold subsumed, merge_astate; simplify.
    cases (x0 ==v x); subst; simplify.
    cases (s $? x); try equality.
    invert H1; eauto.
    cases (s $? x); try equality.
    invert 1; eauto.

    eapply subsumed_trans; try apply IHrunAllAssignments; eauto.
    unfold subsumed; simplify.
    cases (x0 ==v x1); subst; simplify.
    invert H1; eauto.
    unfold merge_astate; simplify.
    cases (s $? x1); try equality.
    cases (x ==v x1); subst; simplify; try equality.
    invert H1; eauto.
    cases (s $? x1); try equality.
    invert H1; eauto.
  Qed.

  Lemma subsumed_merge_both : forall a, absint_sound a
    -> absint_complete a
    -> forall s1 s2 s : astate a,
      subsumed s1 s
      -> subsumed s2 s
      -> subsumed (merge_astate s1 s2) s.
  Proof.
    unfold subsumed, merge_astate; simplify.
    specialize (H1 x).
    specialize (H2 x).
    cases (s1 $? x); auto.
    cases (s2 $? x); auto.
    simplify.
    unfold absint_complete in *; eauto.
  Qed.

  Lemma subsumed_add : forall a, absint_sound a
    -> forall (s1 s2 : astate a) x v1 v2,
    subsumed s1 s2
    -> (forall n, a.(Represents) n v1 -> a.(Represents) n v2)
    -> subsumed (s1 $+ (x, v1)) (s2 $+ (x, v2)).
  Proof.
    unfold subsumed; simplify.
    cases (x ==v x0); subst; simplify; eauto.
    invert H2; eauto.
    specialize (H0 x0); eauto.
  Qed.

  Hint Resolve subsumed_add.

  Lemma iterate_ok' : forall a, absint_sound a
    -> absint_complete a
    -> forall c (s0 s s' : astate a),
      iterate c s s'
      -> subsumed s0 s
      -> invariantFor (flow_insensitive_trsys s0 c) (fun s'' => subsumed s'' s').
  Proof.
    induct 3; simplify.

    apply invariant_induction; simplify; propositional; subst; auto.

    invert H4; auto.
    eapply runAllAssignments_ok in H5; eauto.
    apply subsumed_merge_both; auto.
    unfold subsumed, merge_astate; simplify.
    assert (subsumed s1 s) by assumption.
    specialize (H4 x0).
    specialize (H5 x0).
    cases (x ==v x0); subst; simplify; eauto.

    eauto using subsumed_trans.
  Qed.

  Theorem iterate_ok : forall a, absint_sound a
    -> absint_complete a
    -> forall c (s0 s : astate a),
      iterate c s0 s
      -> invariantFor (flow_insensitive_trsys s0 c) (fun s' => subsumed s' s).
  Proof.
    eauto using iterate_ok'.
  Qed.

  Ltac insensitive_simpl := unfold merge_astate; simplify; repeat simplify_map.
  Ltac runAllAssignments := repeat (constructor; insensitive_simpl).
  Ltac iterate1 := eapply IterateStep; [ simplify; runAllAssignments | ].
  Ltac iterate_done := eapply IterateDone; simplify; runAllAssignments.

  Definition straightline :=
    "a" <- 7;;
    "b" <- "b" + 2 * "a";;
    "a" <- "a" + "b".

  Lemma final_even : forall (s s' : astate parity_absint) v x,
    insensitive_compatible s v
    -> subsumed s s'
    -> s' $? x = Some Even
    -> exists n, v $? x = Some n /\ isEven n.
  Proof.
    unfold insensitive_compatible, subsumed; simplify.
    specialize (H x); specialize (H0 x).
    cases (s $? x); simplify.

    rewrite Heq in *.
    assert (Some t = Some t) by equality.
    apply H in H2.
    first_order.

    eapply H0 in H1.
    invert H1.
    eauto.
    assumption.

    specialize (H2 1).
    invert H2; try (exfalso; eauto).

    rewrite Heq in *.
    equality.
  Qed.

  Theorem straightline_even :
    invariantFor (trsys_of ($0 $+ ("a", 0) $+ ("b", 0)) straightline)
                 (fun p => snd p = Skip
                           -> exists n, fst p $? "b" = Some n /\ isEven n).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold straightline.
    eapply invariant_simulates.
    apply insensitive_simulates with (s := $0 $+ ("a", Even) $+ ("b", Even))
                                     (a := parity_absint).
    apply parity_sound.
    unfold insensitive_compatible; simplify.
    cases (x ==v "b"); simplify.
    invert H; eauto.
    cases (x ==v "a"); simplify.
    invert H; eauto.
    equality.

    apply iterate_ok.
    apply parity_sound.
    apply parity_complete.

    iterate1.
    iterate_done.

    invert 1.
    invert H0; simplify.
    eapply final_even; eauto; simplify; equality.
  Qed.

  Definition less_straightline :=
    "a" <- 7;;
    when "c" then
      "b" <- "b" + 2 * "a"
    else
      "b" <- 18
    done.

  Theorem less_straightline_even :
    invariantFor (trsys_of ($0 $+ ("a", 0) $+ ("b", 0)) less_straightline)
                 (fun p => snd p = Skip
                           -> exists n, fst p $? "b" = Some n /\ isEven n).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold less_straightline.
    eapply invariant_simulates.
    apply insensitive_simulates with (s := $0 $+ ("a", Even) $+ ("b", Even))
                                     (a := parity_absint).
    apply parity_sound.
    unfold insensitive_compatible; simplify.
    cases (x ==v "b"); simplify.
    invert H; eauto.
    cases (x ==v "a"); simplify.
    invert H; eauto.
    equality.

    apply iterate_ok.
    apply parity_sound.
    apply parity_complete.

    iterate1.
    iterate_done.

    invert 1.
    invert H0; simplify.
    eapply final_even; eauto; simplify; equality.
  Qed.

  Definition loopy :=
    "n" <- 100;;
    "a" <- 0;;
    while "n" loop
      "a" <- "a" + "n";;
      "n" <- "n" - 2
    done.

  Theorem loopy_even :
    invariantFor (trsys_of ($0 $+ ("n", 0) $+ ("a", 0)) loopy)
                 (fun p => snd p = Skip
                           -> exists n, fst p $? "n" = Some n /\ isEven n).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold loopy.
    eapply invariant_simulates.
    apply insensitive_simulates with (s := $0 $+ ("n", Even) $+ ("a", Even))
                                     (a := parity_absint).
    apply parity_sound.
    unfold insensitive_compatible; simplify.
    cases (x ==v "a"); simplify.
    invert H; eauto.
    cases (x ==v "n"); simplify.
    invert H; eauto.
    equality.

    apply iterate_ok.
    apply parity_sound.
    apply parity_complete.

    iterate_done.

    invert 1.
    invert H0; simplify.
    eapply final_even; eauto; simplify; equality.
  Qed.


  (** * Flow-sensitive analysis *)

  Definition compatible a (s : astate a) (v : valuation) : Prop :=
    forall x xa, s $? x = Some xa
                 -> exists n, v $? x = Some n
                              /\ a.(Represents) n xa.

  Lemma compatible_add : forall a (s : astate a) v x na n,
    compatible s v
    -> a.(Represents) n na
    -> compatible (s $+ (x, na)) (v $+ (x, n)).
  Proof.
    unfold compatible; simplify.
    cases (x ==v x0); simplify; eauto.
    invert H1; eauto.
  Qed.

  Hint Resolve compatible_add.

  Theorem absint_interp_ok2 : forall a, absint_sound a
    -> forall (s : astate a) v e,
      compatible s v
      -> a.(Represents) (interp e v) (absint_interp e s).
  Proof.
    induct e; simplify; eauto.
    cases (s $? x); auto.
    unfold compatible in H0.
    apply H0 in Heq.
    invert Heq.
    propositional.
    rewrite H2.
    assumption.
  Qed.

  Hint Resolve absint_interp_ok2.

  Definition astates (a : absint) := fmap cmd (astate a).

  Fixpoint absint_step a (s : astate a) (c : cmd) (wrap : cmd -> cmd) : option (astates a) :=
    match c with
    | Skip => None
    | Assign x e => Some ($0 $+ (wrap Skip, s $+ (x, absint_interp e s)))
    | Sequence c1 c2 =>
      match absint_step s c1 (fun c => wrap (Sequence c c2)) with
      | None => Some ($0 $+ (wrap c2, s))
      | v => v
      end
    | If e then_ else_ => Some ($0 $+ (wrap then_, s) $+ (wrap else_, s))
    | While e body => Some ($0 $+ (wrap Skip, s) $+ (wrap (Sequence body (While e body)), s))
    end.

  Lemma command_equal : forall c1 c2 : cmd, sumbool (c1 = c2) (c1 <> c2).
  Proof.
    repeat decide equality.
  Qed.

  Theorem absint_step_ok : forall a, absint_sound a
    -> forall (s : astate a) v, compatible s v
    -> forall c v' c', step (v, c) (v', c')
                       -> forall wrap, exists ss s', absint_step s c wrap = Some ss
                                                     /\ ss $? wrap c' = Some s'
                                                     /\ compatible s' v'.
  Proof.
    induct 2; simplify.

    do 2 eexists; propositional.
    simplify; equality.
    eauto.

    eapply IHstep in H0; auto.
    invert H0.
    invert H2.
    propositional.
    rewrite H2.
    eauto.

    do 2 eexists; propositional.
    simplify; equality.
    assumption.

    do 2 eexists; propositional.
    cases (command_equal (wrap c') (wrap else_)).
    simplify; equality.
    simplify; equality.
    assumption.

    do 2 eexists; propositional.
    simplify; equality.
    assumption.

    do 2 eexists; propositional.
    simplify; equality.
    assumption.

    do 2 eexists; propositional.
    cases (command_equal (wrap Skip) (wrap (body;; while e loop body done))).
    simplify; equality.
    simplify; equality.
    assumption.
  Qed.

  Inductive abs_step a : astate a * cmd -> astate a * cmd -> Prop :=
  | AbsStep : forall s c ss s' c',
    absint_step s c (fun x => x) = Some ss
    -> ss $? c' = Some s'
    -> abs_step (s, c) (s', c').

  Hint Constructors abs_step.

  Definition absint_trsys a (c : cmd) := {|
    Initial := {($0, c)};
    Step := abs_step (a := a)
  |}.

  Inductive Rabsint a : valuation * cmd -> astate a * cmd -> Prop :=
  | RAbsint : forall v s c,
    compatible s v
    -> Rabsint (v, c) (s, c).

  Hint Constructors abs_step Rabsint.

  Theorem absint_simulates : forall a v c,
    absint_sound a
    -> simulates (Rabsint (a := a)) (trsys_of v c) (absint_trsys a c).
  Proof.
    simplify.
    constructor; simplify.

    exists ($0, c); propositional.
    subst.
    constructor.
    unfold compatible.
    simplify.
    equality.

    invert H0.
    cases st1'.
    eapply absint_step_ok in H1; eauto.
    invert H1.
    invert H0.
    propositional.
    eauto.
  Qed.

  Definition merge_astates a : astates a -> astates a -> astates a :=
    merge (fun x y =>
             match x with
             | None => y
             | Some x' =>
               match y with
               | None => Some x'
               | Some y' => Some (merge_astate x' y')
               end
             end).

  Inductive oneStepClosure a : astates a -> astates a -> Prop :=
  | OscNil :
    oneStepClosure $0 $0
  | OscCons : forall ss c s ss' ss'',
    oneStepClosure ss ss'
    -> match absint_step s c (fun x => x) with
       | None => ss'
       | Some ss'' => merge_astates ss'' ss'
       end = ss''
    -> oneStepClosure (ss $+ (c, s)) ss''.

  Definition subsumeds a (ss1 ss2 : astates a) :=
    forall c s1, ss1 $? c = Some s1
                 -> exists s2, ss2 $? c = Some s2
                               /\ subsumed s1 s2.

  Theorem subsumeds_refl : forall a (ss : astates a),
    subsumeds ss ss.
  Proof.
    unfold subsumeds; simplify; eauto.
  Qed.

  Hint Resolve subsumeds_refl.

  Inductive interpret a : astates a -> astates a -> astates a -> Prop :=
  | InterpretDone : forall ss1 any ss2,
    oneStepClosure ss1 ss2
    -> subsumeds ss2 ss1
    -> interpret ss1 any ss1

  | InterpretStep : forall ss worklist ss' ss'',
    oneStepClosure worklist ss'
    -> interpret (merge_astates ss ss') ss' ss''
    -> interpret ss worklist ss''.

  Lemma oneStepClosure_sound : forall a, absint_sound a
    -> forall ss ss' : astates a, oneStepClosure ss ss'
    -> forall c s s' c', ss $? c = Some s
                         -> abs_step (s, c) (s', c')
                            -> exists s'', ss' $? c' = Some s''
                                           /\ subsumed s' s''.
  Proof.
    induct 2; simplify.

    equality.

    cases (command_equal c c0); subst; simplify.

    invert H2.
    invert H3.
    rewrite H5.
    unfold merge_astates; simplify.
    rewrite H7.
    cases (ss' $? c').
    eexists; propositional.
    unfold subsumed; simplify.
    unfold merge_astate; simplify.
    cases (s' $? x); try equality.
    cases (a0 $? x); simplify; try equality.
    invert H1; eauto.
    eauto.

    apply IHoneStepClosure in H3; auto.
    invert H3; propositional.
    cases (absint_step s c (fun x => x)); eauto.
    unfold merge_astates; simplify.
    rewrite H3.
    cases (a0 $? c'); eauto.
    eexists; propositional.
    unfold subsumed; simplify.
    unfold merge_astate; simplify.
    specialize (H4 x0).
    cases (s' $? x0).
    cases (a1 $? x0); try equality.
    cases (x $? x0); try equality.
    invert 1.
    eauto.

    rewrite H4.
    cases (a1 $? x0); equality.
  Qed.

  Lemma subsumeds_add : forall a (ss1 ss2 : astates a) c s1 s2,
    subsumeds ss1 ss2
    -> subsumed s1 s2
    -> subsumeds (ss1 $+ (c, s1)) (ss2 $+ (c, s2)).
  Proof.
    unfold subsumeds; simplify.
    cases (command_equal c c0); subst; simplify; eauto.
    invert H1; eauto.
  Qed.

  Hint Resolve subsumeds_add.



  Lemma absint_step_monotone_None : forall a (s : astate a) c wrap,
      absint_step s c wrap = None
      -> forall s' : astate a, absint_step s' c wrap = None.
  Proof.
    induct c; simplify; try equality.
    cases (absint_step s c1 (fun c => wrap (c;; c2))); equality.
  Qed.

  Lemma absint_step_monotone : forall a, absint_sound a
      -> forall (s : astate a) c wrap ss,
        absint_step s c wrap = Some ss
        -> forall s', subsumed s s'
                      -> exists ss', absint_step s' c wrap = Some ss'
                                     /\ subsumeds ss ss'.
  Proof.
    induct c; simplify.

    equality.

    invert H0.
    eexists; propositional.
    eauto.
    apply subsumeds_add; eauto.

    cases (absint_step s c1 (fun c => wrap (c;; c2))).

    invert H0.
    eapply IHc1 in Heq; eauto.
    invert Heq; propositional.
    rewrite H2; eauto.

    invert H0.
    eapply absint_step_monotone_None in Heq; eauto.
    rewrite Heq; eauto.

    invert H0; eauto.

    invert H0; eauto.
  Qed.

  Lemma abs_step_monotone : forall a, absint_sound a
    -> forall (s : astate a) c s' c',
      abs_step (s, c) (s', c')
      -> forall s1, subsumed s s1
                    -> exists s1', abs_step (s1, c) (s1', c')
                                   /\ subsumed s' s1'.
  Proof.
    invert 2; simplify.
    eapply absint_step_monotone in H4; eauto.
    invert H4; propositional.
    apply H3 in H6.
    invert H6; propositional; eauto.
  Qed.    

  Lemma interpret_sound' : forall c a, absint_sound a
    -> forall ss worklist ss' : astates a, interpret ss worklist ss'
      -> ss $? c = Some $0
      -> invariantFor (absint_trsys a c) (fun p => exists s, ss' $? snd p = Some s
                                                             /\ subsumed (fst p) s).
  Proof.
    induct 2; simplify; subst.

    apply invariant_induction; simplify; propositional; subst; simplify; eauto.

    invert H3; propositional.
    cases s.
    cases s'.
    simplify.
    eapply abs_step_monotone in H4; eauto.
    invert H4; propositional.
    eapply oneStepClosure_sound in H4; eauto.
    invert H4; propositional.
    eapply H1 in H4.
    invert H4; propositional.
    eauto using subsumed_trans.

    apply IHinterpret.
    unfold merge_astates; simplify.
    rewrite H2.
    cases (ss' $? c); trivial.
    unfold merge_astate; simplify; equality.
  Qed.

  Theorem interpret_sound : forall c a (ss : astates a),
    absint_sound a
    -> interpret ($0 $+ (c, $0)) ($0 $+ (c, $0)) ss
    -> invariantFor (absint_trsys a c) (fun p => exists s, ss $? snd p = Some s
                                                           /\ subsumed (fst p) s).
  Proof.
    simplify.
    eapply interpret_sound'; eauto.
    simplify; equality.
  Qed.



  Lemma merge_astates_fok_parity : forall x : option (astate parity_absint),
    match x with Some x' => Some x' | None => None end = x.
  Proof.
    simplify; cases x; equality.
  Qed.

  Lemma merge_astates_fok2_parity : forall x (y : option (astate parity_absint)),
      match y with
      | Some y' => Some (merge_astate x y')
      | None => Some x
      end = None -> False.
  Proof.
    simplify; cases y; equality.
  Qed.

  Hint Resolve merge_astates_fok_parity merge_astates_fok2_parity.

  Lemma subsumeds_empty : forall a (ss : astates a),
    subsumeds $0 ss.
  Proof.
    unfold subsumeds; simplify.
    equality.
  Qed.

  Lemma subsumeds_add_left : forall a (ss1 ss2 : astates a) c s,
    ss2 $? c = Some s
    -> subsumeds ss1 ss2
    -> subsumeds (ss1 $+ (c, s)) ss2.
  Proof.
    unfold subsumeds; simplify.
    cases (command_equal c c0); subst; simplify; eauto.
    invert H1; eauto.
  Qed.

  Ltac interpret_simpl := unfold merge_astates, merge_astate;
                         simplify; repeat simplify_map.

  Ltac oneStepClosure := apply OscNil
                         || (eapply OscCons; [ oneStepClosure
                                             | interpret_simpl; reflexivity ]).

  Ltac interpret1 := eapply InterpretStep; [ oneStepClosure | interpret_simpl ].

  Ltac interpret_done := eapply InterpretDone; [ oneStepClosure
    | repeat (apply subsumeds_add_left || apply subsumeds_empty); (simplify; equality) ].

  Definition simple :=
    "a" <- 7;;
    "b" <- 8;;
    "a" <- "a" + "b";;
    "b" <- "a" * "b".

  Lemma final_even2 : forall (s s' : astate parity_absint) v x,
    compatible s v
    -> subsumed s s'
    -> s' $? x = Some Even
    -> exists n, v $? x = Some n /\ isEven n.
  Proof.
    unfold insensitive_compatible, subsumed; simplify.
    specialize (H x); specialize (H0 x).
    cases (s $? x); simplify.

    rewrite Heq in *.
    assert (Some t = Some t) by equality.
    apply H in H2.
    first_order.

    eapply H0 in H1.
    invert H1.
    eauto.
    assumption.

    rewrite Heq in *.
    equality.
  Qed.

  Theorem simple_even : forall v,
    invariantFor (trsys_of v simple) (fun p => snd p = Skip
                                               -> exists n, fst p $? "b" = Some n /\ isEven n).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold simple.
    eapply invariant_simulates.
    apply absint_simulates with (a := parity_absint).
    apply parity_sound.

    apply interpret_sound.
    apply parity_sound.

    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret_done.

    invert 1.
    first_order.
    invert H0; simplify.
    invert H1.
    eapply final_even2; eauto; simplify; try equality.
  Qed.

  Definition branchy :=
    "a" <- 8;;
    when "c" then
      "b" <- "a" + 4
    else
      "b" <- 7
    done.

  Theorem branchy_even : forall v,
    invariantFor (trsys_of v branchy) (fun p => snd p = Skip
                                                -> exists n, fst p $? "a" = Some n /\ isEven n).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold branchy.
    eapply invariant_simulates.
    apply absint_simulates with (a := parity_absint).
    apply parity_sound.

    apply interpret_sound.
    apply parity_sound.

    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret_done.

    invert 1.
    first_order.
    invert H0; simplify.
    invert H1.
    eapply final_even2; eauto; simplify; equality.
  Qed.

  Definition easy :=
    "n" <- 10;;
    while "n" loop
      "n" <- "n" - 2
    done.

  Theorem easy_even : forall v,
    invariantFor (trsys_of v easy) (fun p => snd p = Skip
                                             -> exists n, fst p $? "n" = Some n /\ isEven n).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold easy.
    eapply invariant_simulates.
    apply absint_simulates with (a := parity_absint).
    apply parity_sound.

    apply interpret_sound.
    apply parity_sound.

    interpret1.
    interpret1.
    interpret1.
    interpret_done.

    invert 1.
    first_order.
    invert H0; simplify.
    invert H1.
    eapply final_even2; eauto; simplify; equality.
  Qed.

  Theorem loopy_even_again : forall v,
    invariantFor (trsys_of v loopy) (fun p => snd p = Skip
                                              -> exists n, fst p $? "n" = Some n /\ isEven n).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold loopy.
    eapply invariant_simulates.
    apply absint_simulates with (a := parity_absint).
    apply parity_sound.

    apply interpret_sound.
    apply parity_sound.

    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret_done.

    invert 1.
    first_order.
    invert H0; simplify.
    invert H1.
    eapply final_even2; eauto; simplify; equality.
  Qed.


  (** * Another abstract interpretation: intervals *)

  Record interval := {
    Lower : nat;
    Upper : option nat
  }.

  Infix "<=?" := le_lt_dec.

  Definition impossible (x : interval) :=
    match x.(Upper) with
    | None => false
    | Some u => if x.(Lower) <=? u then false else true
    end.

  Definition interval_join (x y : interval) :=
    if impossible x then y
    else if impossible y then x
         else {| Lower := min x.(Lower) y.(Lower);
                 Upper := match x.(Upper) with
                          | None => None
                          | Some x2 =>
                            match y.(Upper) with
                            | None => None
                            | Some y2 => Some (max x2 y2)
                            end
                          end |}.

  Lemma interval_join_impossible1 : forall x y,
    impossible x = true
    -> interval_join x y = y.
  Proof.
    unfold interval_join; simplify.
    rewrite H; equality.
  Qed.

  Lemma interval_join_impossible2 : forall x y,
    impossible x = false
    -> impossible y = true
    -> interval_join x y = x.
  Proof.
    unfold interval_join; simplify.
    rewrite H, H0; equality.
  Qed.

  Lemma interval_join_possible : forall x y,
    impossible x = false
    -> impossible y = false
    -> interval_join x y = {| Lower := min x.(Lower) y.(Lower);
                              Upper := match x.(Upper) with
                                       | None => None
                                       | Some x2 =>
                                         match y.(Upper) with
                                         | None => None
                                         | Some y2 => Some (max x2 y2)
                                         end
                                       end |}.
  Proof.
    unfold interval_join; simplify.
    rewrite H, H0; equality.
  Qed.

  Hint Rewrite interval_join_impossible1 interval_join_impossible2 interval_join_possible
       using assumption.

  Definition interval_combine (f : nat -> nat -> nat) (x y : interval) :=
    if impossible x || impossible y then
      {| Lower := 1; Upper := Some 0 |}
    else {| Lower := f x.(Lower) y.(Lower);
            Upper := match x.(Upper) with
                     | None => None
                     | Some x2 =>
                       match y.(Upper) with
                       | None => None
                       | Some y2 => Some (f x2 y2)
                       end
                     end |}.

  Lemma interval_combine_possible_fwd : forall f x y,
    impossible x = false
    -> impossible y = false
    -> interval_combine f x y
       = {| Lower := f x.(Lower) y.(Lower);
            Upper := match x.(Upper) with
                     | None => None
                     | Some x2 =>
                       match y.(Upper) with
                       | None => None
                       | Some y2 => Some (f x2 y2)
                       end
                     end |}.
  Proof.
    unfold interval_combine; simplify.
    rewrite H, H0; simplify; equality.
  Qed.

  Lemma interval_combine_possible_bwd : forall f x y,
    impossible (interval_combine f x y) = false
    -> impossible x = false /\ impossible y = false.
  Proof.
    unfold interval_combine; simplify.
    cases (impossible x); simplify.
    unfold impossible in H; simplify; equality.
    cases (impossible y); simplify; equality.
  Qed.

  Hint Rewrite interval_combine_possible_fwd using assumption.

  Definition interval_subtract (x y : interval) :=
    if impossible x || impossible y then
      {| Lower := 1; Upper := Some 0 |}
    else
      {| Lower := match y.(Upper) with
                  | None => 0
                  | Some y2 => x.(Lower) - y2
                  end;
         Upper := match x.(Upper) with
                  | None => None
                  | Some x2 => Some (x2 - y.(Lower))
                  end |}.

  Lemma interval_subtract_possible_fwd : forall x y,
    impossible x = false
    -> impossible y = false
    -> interval_subtract x y
       = {| Lower := match y.(Upper) with
                     | None => 0
                     | Some y2 => x.(Lower) - y2
                     end;
            Upper := match x.(Upper) with
                     | None => None
                     | Some x2 => Some (x2 - y.(Lower))
                     end |}.
  Proof.
    unfold interval_subtract; simplify.
    rewrite H, H0; simplify; equality.
  Qed.

  Lemma interval_subtract_possible_bwd : forall x y,
    impossible (interval_subtract x y) = false
    -> impossible x = false /\ impossible y = false.
  Proof.
    unfold interval_subtract; simplify.
    cases (impossible x); simplify.
    unfold impossible in H; simplify; equality.
    cases (impossible y); simplify; equality.
  Qed.

  Hint Rewrite interval_subtract_possible_fwd using assumption.

  Record interval_rep (n : nat) (i : interval) : Prop := {
    BoundedBelow : i.(Lower) <= n;
    BoundedAbove : match i.(Upper) with
                   | None => True
                   | Some n2 => n <= n2
                   end
  }.

  Hint Constructors interval_rep.

  Definition interval_absint := {|
    Top := {| Lower := 0; Upper := None |};
    Constant := fun n => {| Lower := n;
                            Upper := Some n |};
    Add := interval_combine plus;
    Subtract := interval_subtract;
    Multiply := interval_combine mult;
    Join := interval_join;
    Represents := interval_rep
  |}.

  Hint Resolve mult_le_compat.

  Lemma interval_imply : forall k1 k2 u1 u2,
      impossible {| Lower := k1; Upper := u1 |} = false
      -> (forall n,
             interval_rep n {| Lower := k1; Upper := u1 |}
             -> interval_rep n {| Lower := k2; Upper := u2 |})
      -> k1 >= k2
         /\ match u2 with
            | None => True
            | Some u2' => match u1 with
                          | None => False
                          | Some u1' => u1' <= u2'
                          end
            end
         /\ impossible {| Lower := k2; Upper := u2 |} = false.
  Proof.
    simplify.
    assert (k1 >= k2 \/ k1 < k2) by linear_arithmetic.
    invert H1.
    propositional.

    cases u2; auto.
    cases u1.
    assert (n >= n0 \/ n < n0) by linear_arithmetic.
    propositional.
    exfalso.
    assert (interval_rep n0 {| Lower := k2; Upper := Some n |}).
    apply H0.
    constructor; simplify; auto.
    unfold impossible in H; simplify.
    cases (k1 <=? n0); equality.
    invert H1; simplify; auto.
    linear_arithmetic.
    assert (interval_rep (S (max k1 n)) {| Lower := k2; Upper := Some n |}).
    apply H0.
    constructor; simplify; auto.
    linear_arithmetic.
    invert H1; simplify; linear_arithmetic.

    unfold impossible; simplify.
    cases u2; try equality.
    cases (k2 <=? n); try equality; try linear_arithmetic.
    exfalso.
    assert (interval_rep k1 {| Lower := k2; Upper := Some n |}).
    apply H0.
    unfold impossible in H; simplify.
    cases u1.
    cases (k1 <=? n0); try equality.
    constructor; simplify; linear_arithmetic.
    constructor; simplify; auto; linear_arithmetic.
    invert H1; simplify.
    linear_arithmetic.

    exfalso.
    assert (interval_rep k1 {| Lower := k2; Upper := u2 |}).
    apply H0.
    unfold impossible in H; simplify.
    cases u1.
    cases (k1 <=? n); try equality.
    constructor; simplify; linear_arithmetic.
    constructor; simplify; auto; linear_arithmetic.
    invert H1; simplify; try linear_arithmetic.
  Qed.

  Lemma impossible_sound : forall n x,
    interval_rep n x
    -> impossible x = true
    -> False.
  Proof.
    invert 1.
    unfold impossible.
    cases (Upper x); simplify; try equality.
    cases (Lower x <=? n0); try equality.
    linear_arithmetic.
  Qed.

  Lemma mult_bound1 : forall a b n a' b',
    a' * b' <= n
    -> a <= a'
    -> b <= b'
    -> a * b <= n.
  Proof.
    simplify.
    transitivity (a' * b'); eauto.
  Qed.

  Lemma mult_bound2 : forall a b n a' b',
    n <= a' * b'
    -> a' <= a
    -> b' <= b
    -> n <= a * b.
  Proof.
    simplify.
    transitivity (a' * b'); eauto.
  Qed.

  Hint Immediate mult_bound1 mult_bound2.

  Theorem interval_sound : absint_sound interval_absint.
  Proof.
    constructor; simplify; eauto;
    repeat match goal with
           | [ x : interval |- _ ] => cases x
           end; simplify;
    (repeat match goal with
            | [ _ : interval_rep _ (interval_join ?x ?y) |- _ ] =>
              cases (impossible x); simplify; eauto;
              cases (impossible y); simplify; eauto
            | [ H : interval_rep _ ?x |- _ ] =>
              cases (impossible x); [ exfalso; solve [ eauto using impossible_sound ] | invert H ]
            | [ H : impossible _ = _ |- _ ] => apply interval_combine_possible_bwd in H; propositional; simplify
            | [ H : impossible _ = _ |- _ ] => apply interval_subtract_possible_bwd in H; propositional; simplify
            | [ H : forall x, _ |- _ ] => apply interval_imply in H; auto
            | [ |- context[interval_join ?x _] ] =>
              match goal with
              | [ _ : impossible x = _ |- _ ] => fail 1
              | _ => cases (impossible x); simplify
              end
            | [ |- context[interval_join _ ?x] ] =>
              match goal with
              | [ _ : impossible x = _ |- _ ] => fail 1
              | _ => cases (impossible x); simplify
              end
            end; propositional; constructor; simplify;
     repeat match goal with
            | [ H : Some _ = Some _ |- _] => invert H
            | [ _ : context[match ?X with _ => _ end] |- _ ] => cases X
            | [ |- context[match ?X with _ => _ end] ] => cases X
            end; eauto; try equality; linear_arithmetic).
  Qed.

  Lemma merge_astates_fok_interval : forall x : option (astate interval_absint),
    match x with Some x' => Some x' | None => None end = x.
  Proof.
    simplify; cases x; equality.
  Qed.

  Lemma merge_astates_fok2_interval : forall x (y : option (astate interval_absint)),
      match y with
      | Some y' => Some (merge_astate x y')
      | None => Some x
      end = None -> False.
  Proof.
    simplify; cases y; equality.
  Qed.

  Hint Resolve merge_astates_fok_interval merge_astates_fok2_interval.

  Lemma final_upper : forall (s s' : astate interval_absint) v x l u,
    compatible s v
    -> subsumed s s'
    -> s' $? x = Some {| Lower := l; Upper := Some u |}
    -> exists n, v $? x = Some n /\ n <= u.
  Proof.
    unfold compatible, subsumed; simplify.
    specialize (H x); specialize (H0 x).
    cases (s $? x); simplify.

    rewrite Heq in *.
    assert (Some t = Some t) by equality.
    apply H in H2.
    first_order.

    rewrite Heq in *.
    equality.
  Qed.

  Hint Rewrite Nat.min_l Nat.min_r Nat.max_l Nat.max_r using linear_arithmetic.

  Definition interval_test :=
    "a" <- 6;;
    "b" <- 7;;
    when "c" then
      "a" <- "a" + "b"
    else
      "b" <- "a" * "b"
    done.

  Theorem interval_test_ok : forall v,
    invariantFor (trsys_of v interval_test)
                 (fun p => snd p = Skip
                           -> exists n, fst p $? "b" = Some n /\ n <= 42).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold interval_test.
    eapply invariant_simulates.
    apply absint_simulates with (a := interval_absint).
    apply interval_sound.

    apply interpret_sound.
    apply interval_sound.

    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    unfold interval_join, interval_combine; simplify.
    interpret_done.

    invert 1.
    first_order.
    invert H0; simplify.
    invert H1.
    eapply final_upper; eauto; simplify; equality.
  Qed.


  (** * Let's redo that definition for better termination behavior. *)

  Definition interval_widen (x y : interval) :=
    if impossible x then y
    else if impossible y then x
         else {| Lower := if x.(Lower) <=? y.(Lower) then x.(Lower) else 0;
                 Upper := match x.(Upper) with
                          | None => None
                          | Some x2 =>
                            match y.(Upper) with
                            | None => None
                            | Some y2 => if y2 <=? x2 then Some x2 else None
                            end
                          end |}.

  Lemma interval_widen_impossible1 : forall x y,
    impossible x = true
    -> interval_widen x y = y.
  Proof.
    unfold interval_widen; simplify.
    rewrite H; equality.
  Qed.

  Lemma interval_widen_impossible2 : forall x y,
    impossible x = false
    -> impossible y = true
    -> interval_widen x y = x.
  Proof.
    unfold interval_widen; simplify.
    rewrite H, H0; equality.
  Qed.

  Lemma interval_widen_possible : forall x y,
    impossible x = false
    -> impossible y = false
    -> interval_widen x y = {| Lower := if x.(Lower) <=? y.(Lower) then x.(Lower) else 0;
                               Upper := match x.(Upper) with
                                        | None => None
                                        | Some x2 =>
                                          match y.(Upper) with
                                          | None => None
                                          | Some y2 => if y2 <=? x2 then Some x2 else None
                                          end
                                        end |}.
  Proof.
    unfold interval_widen; simplify.
    rewrite H, H0; equality.
  Qed.

  Hint Rewrite interval_widen_impossible1 interval_widen_impossible2 interval_widen_possible
       using assumption.

  Definition interval_absint_widening := {|
    Top := {| Lower := 0; Upper := None |};
    Constant := fun n => {| Lower := n;
                            Upper := Some n |};
    Add := interval_combine plus;
    Subtract := interval_subtract;
    Multiply := interval_combine mult;
    Join := interval_widen;
    Represents := interval_rep
  |}.

  Theorem interval_widening_sound : absint_sound interval_absint_widening.
  Proof.
    constructor; simplify; eauto;
    repeat match goal with
           | [ x : interval |- _ ] => cases x
           end; simplify;
    (repeat match goal with
            | [ _ : interval_rep _ (interval_widen ?x ?y) |- _ ] =>
              cases (impossible x); simplify; eauto;
              cases (impossible y); simplify; eauto
            | [ H : interval_rep _ ?x |- _ ] =>
              cases (impossible x); [ exfalso; solve [ eauto using impossible_sound ] | invert H ]
            | [ H : impossible _ = _ |- _ ] => apply interval_combine_possible_bwd in H; propositional; simplify
            | [ H : impossible _ = _ |- _ ] => apply interval_subtract_possible_bwd in H; propositional; simplify
            | [ H : forall x, _ |- _ ] => apply interval_imply in H; auto
            | [ |- context[interval_widen ?x _] ] =>
              match goal with
              | [ _ : impossible x = _ |- _ ] => fail 1
              | _ => cases (impossible x); simplify
              end
            | [ |- context[interval_widen _ ?x] ] =>
              match goal with
              | [ _ : impossible x = _ |- _ ] => fail 1
              | _ => cases (impossible x); simplify
              end
            end; propositional; constructor; simplify;
     repeat match goal with
            | [ H : Some _ = Some _ |- _] => invert H
            | [ _ : context[match ?X with _ => _ end] |- _ ] => cases X
            | [ |- context[match ?X with _ => _ end] ] => cases X
            end; eauto; try equality; linear_arithmetic).
  Qed.

  Lemma merge_astates_fok_interval_widening : forall x : option (astate interval_absint_widening),
    match x with Some x' => Some x' | None => None end = x.
  Proof.
    simplify; cases x; equality.
  Qed.

  Lemma merge_astates_fok2_interval_widening : forall x (y : option (astate interval_absint_widening)),
      match y with
      | Some y' => Some (merge_astate x y')
      | None => Some x
      end = None -> False.
  Proof.
    simplify; cases y; equality.
  Qed.

  Hint Resolve merge_astates_fok_interval_widening merge_astates_fok2_interval_widening.

  Definition ge7 :=
    "a" <- 7;;
    while "a" loop
      "a" <- "a" + 3
    done.

  Lemma final_lower_widening : forall (s s' : astate interval_absint_widening) v x l,
    compatible s v
    -> subsumed s s'
    -> s' $? x = Some {| Lower := l; Upper := None |}
    -> exists n, v $? x = Some n /\ n >= l.
  Proof.
    unfold compatible, subsumed; simplify.
    specialize (H x); specialize (H0 x).
    cases (s $? x); simplify.

    rewrite Heq in *.
    assert (Some t = Some t) by equality.
    apply H in H2.
    first_order.

    rewrite Heq in *.
    equality.
  Qed.

  Theorem ge7_ok : forall v,
    invariantFor (trsys_of v ge7)
                 (fun p => snd p = Skip
                           -> exists n, fst p $? "a" = Some n /\ n >= 7).
  Proof.
    simplify.
    eapply invariant_weaken.

    unfold ge7.
    eapply invariant_simulates.
    apply absint_simulates with (a := interval_absint_widening).
    apply interval_widening_sound.

    apply interpret_sound.
    apply interval_widening_sound.

    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    interpret1.
    unfold interval_combine, interval_widen; simplify.
    interpret_done.

    invert 1.
    first_order.
    invert H0; simplify.
    invert H1.
    eapply final_lower_widening; eauto; simplify; equality.
  Qed.

End SimpleAbstractInterpreter.
