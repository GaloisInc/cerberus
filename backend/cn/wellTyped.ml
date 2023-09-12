module LS = LogicalSorts
module BT = BaseTypes
module SymSet = Set.Make(Sym)
module TE = TypeErrors
module RE = Resources
module RET = ResourceTypes
module LRT = LogicalReturnTypes
module AT = ArgumentTypes
module LAT = LogicalArgumentTypes
module Mu = Mucore
module IdSet = Set.Make(Id)

open Global
open TE
open Pp
open Locations


open Typing
open Effectful.Make(Typing)


let ensure_base_type = Typing.ensure_base_type

let illtyped_index_term (loc: loc) it has expected ctxt =
  {loc = loc; msg = TypeErrors.Illtyped_it {it = IT.pp it; has = BT.pp has; expected; o_ctxt = Some ctxt}}


let ensure_integer_or_real_type (loc : loc) it = 
  let open BT in
  match IT.bt it with
  | (Integer | Real) -> return ()
  | _ -> 
     let expect = "integer or real type" in
     fail (illtyped_index_term loc it (IT.bt it) expect)

let ensure_set_type loc it = 
  let open BT in
  match IT.bt it with
  | Set bt -> return bt
  | _ -> fail (illtyped_index_term loc it (IT.bt it) "set type")

let ensure_list_type loc it = 
  let open BT in
  match IT.bt it with
  | List bt -> return bt
  | _ -> fail (illtyped_index_term loc it (IT.bt it) "list type")

let ensure_map_type loc it = 
  let open BT in
  match IT.bt it with
  | Map (abt, rbt) -> return (abt, rbt)
  | _ -> fail (illtyped_index_term loc it (IT.bt it) "map/array type")

let ensure_same_argument_number loc input_output has ~expect =
  if has = expect then return () else 
    match input_output with
    | `General -> fail (fun _ -> {loc; msg = Number_arguments {has; expect}})
    | `Input -> fail (fun _ -> {loc; msg = Number_input_arguments {has; expect}})
    | `Output -> fail (fun _ -> {loc; msg = Number_output_arguments {has; expect}})




let compare_by_member_id (id,_) (id',_) = Id.compare id id'


let no_duplicate_members loc (have : (Id.t * 'a) list) =
  let _already = 
    ListM.fold_leftM (fun already (id, _) ->
        if IdSet.mem id already 
        then fail (fun _ -> {loc; msg = Duplicate_member id})
        else return (IdSet.add id already)
      ) IdSet.empty have
  in
  return ()

let no_duplicate_members_sorted loc have = 
  let@ () = no_duplicate_members loc have in
  return (List.sort compare_by_member_id have)


let correct_members loc (spec : (Id.t * 'a) list) (have : (Id.t * 'b) list) =
  let needed = IdSet.of_list (List.map fst spec) in
  let already = IdSet.empty in
  let@ needed, already =
    ListM.fold_leftM (fun (needed, already) (id, _) ->
        if IdSet.mem id already then
          fail (fun _ -> {loc; msg = Duplicate_member id})
        else if IdSet.mem id needed then
          return (IdSet.remove id needed, IdSet.add id already)
        else
          fail (fun _ -> {loc; msg = Unexpected_member (List.map fst spec, id)})
      ) (needed, already) have
  in
  match IdSet.elements needed with
  | [] -> return ()
  | missing :: _ -> fail (fun _ -> {loc; msg = Missing_member missing})

let correct_members_sorted_annotated loc spec have = 
  let@ () = correct_members loc spec have in
  let have = List.sort compare_by_member_id have in
  let have_annotated = 
    List.map2 (fun (id,bt) (id',x) ->
        assert (Id.equal id id');
        (bt, (id', x))
      ) spec have
  in
  return have_annotated
  




module WBT = struct

  open BT
  let is_bt loc = 
    let rec aux = function
      | Unit -> 
         return Unit
      | Bool -> 
         return Bool
      | Integer -> 
         return Integer
      | Real -> 
         return Real
      | Alloc_id -> 
         return Alloc_id
      | Loc -> 
         return Loc
      | CType -> 
         return CType
      | Struct tag -> 
         let@ _struct_decl = get_struct_decl loc tag in 
         return (Struct tag)
      | Datatype tag -> 
         let@ _datatype = get_datatype loc tag in 
         return (Datatype tag)
      | Record members -> 
         let@ members = 
           ListM.mapM (fun (id, bt) -> 
               let@ bt = aux bt in
               return (id, bt)
             ) members
         in
         let@ members = no_duplicate_members_sorted loc members in
         return (Record members)
      | Map (abt, rbt) -> 
         let@ abt = aux abt in
         let@ rbt = aux rbt in
         return (Map (abt, rbt))
      | List bt -> 
         let@ bt = aux bt in
         return (List bt)
      | Tuple bts -> 
         let@ bts = ListM.mapM aux bts in
         return (Tuple bts)
      | Set bt -> 
         let@ bt = aux bt in
         return (Set bt)
    in
    fun bt -> aux bt

end


module WLS = struct

  let is_ls = WBT.is_bt

end


module WCT = struct

  open Sctypes

  let is_ct loc = 
    let rec aux = function
      | Void -> return ()
      | Integer _ -> return ()
      | Array (ct, _) -> aux ct
      | Pointer ct -> aux ct
      | Struct tag -> let@ _struct_decl = get_struct_decl loc tag in return ()
      | Function ((_, rct), args, _) -> ListM.iterM aux (rct :: List.map fst args)
    in
    fun ct -> aux ct

end


module WIT = struct


  open BaseTypes
  open IndexTerms

  type t = IndexTerms.t

  let eval = Simplify.IndexTerms.eval

  
  (* let rec check_and_bind_pattern loc bt pat =  *)
  (*   match pat with *)
  (*   | PSym s ->  *)
       

  let rec check_and_bind_pattern loc bt (Pat (pat_, _)) =
    match pat_ with
    | PSym s -> 
       let@ () = add_l s bt (loc, lazy (Sym.pp s)) in
       return (Pat (PSym s, bt))
    | PWild ->
       return (Pat (PWild, bt))
    | PConstructor (s, args) ->
       let@ info = get_datatype_constr loc s in
       let@ () = ensure_base_type loc ~expect:bt (Datatype info.c_datatype_tag) in
       let@ args_annotated = correct_members_sorted_annotated loc info.c_params args in
       let@ args = 
         ListM.mapM (fun (bt', (id', pat')) ->
             let@ pat' = check_and_bind_pattern loc bt' pat' in
             return (id', pat')
           ) args_annotated
       in
       return (Pat (PConstructor (s, args), bt))

  let leading_sym_or_wild = function
    | [] -> assert false
    | Pat (pat_, _) :: _ ->
       match pat_ with
       | PSym _ -> true
       | PWild -> true
       | PConstructor _ -> false

  let expand_constr (constr, constr_info) (case : (BT.t pattern) list) = 
    match case with
    | Pat (PWild, _) :: pats
    | Pat (PSym _, _) :: pats ->
       Some (List.map (fun (_m, bt) -> Pat (PWild, bt)) constr_info.c_params @ pats)
    | Pat (PConstructor (constr', args), _) :: pats 
         when Sym.equal constr constr' ->
       assert (List.for_all2 (fun (m,_) (m',_) -> Id.equal m m') constr_info.c_params args);
       Some (List.map snd args @ pats)
    | Pat (PConstructor (constr', args), _) :: pats ->
       None
    | [] ->
       assert false

       

  (* copying and adjusting Neel's pattern.ml code *)
  let rec cases_complete loc (bts : BT.t list) (cases : ((BT.t pattern) list) list) =
    match bts with
    | [] -> 
       assert (List.for_all (function [] -> true | _ -> false) cases);
       begin match cases with
       | [] -> fail (fun _ -> {loc; msg = Generic !^"Incomplete pattern"})
       | _ -> return ()
       (* | [_(\*[]*\)] -> return () *)
       (* | _::_::_ -> fail (fun _ -> {loc; msg = Generic !^"Duplicate pattern"}) *)
       end
    | bt::bts ->
       if List.for_all leading_sym_or_wild cases then
         cases_complete loc bts (List.map List.tl cases)
       else
         begin match bt with
         | (Unit|Bool|Integer|Real|Alloc_id|Loc|CType|Struct _|
            Record _|Map _|List _|Tuple _|Set _) ->
            failwith "revisit for extended pattern language"
         | Datatype s ->
            let@ dt_info = get_datatype loc s in
            ListM.iterM (fun constr ->
                let@ constr_info = get_datatype_constr loc constr  in
                let relevant_cases = 
                  List.filter_map (expand_constr (constr, constr_info)) cases in
                let member_bts = List.map snd constr_info.c_params in
                cases_complete loc (member_bts @ bts) relevant_cases
              ) dt_info.dt_constrs
         end

  let rec infer =
      fun loc (IT (it, _)) ->
      match it with
      | Sym s ->
         let@ is_a = bound_a s in
         let@ is_l = bound_l s in
         let@ binding = match () with
           | () when is_a -> get_a s
           | () when is_l -> get_l s
           | () -> fail (fun _ -> {loc; msg = TE.Unknown_variable s})
         in
         begin match binding with
         | BaseType bt -> return (IT (Sym s, bt))
         | Value it -> return it
         end
      | Const (Z z) ->
         return (IT (Const (Z z), Integer))
      | Const (Q q) ->
         return (IT (Const (Q q), Real))
      | Const (Pointer p) ->
         return (IT (Const (Pointer p), Loc))
      | Const (Alloc_id p) ->
         return (IT (Const (Alloc_id p), BT.Alloc_id))
      | Const (Bool b) ->
         return (IT (Const (Bool b), BT.Bool))
      | Const Unit ->
         return (IT (Const Unit, BT.Unit))
      | Const (Default bt) -> 
         let@ bt = WBT.is_bt loc bt in
         return (IT (Const (Default bt), bt))
      | Const Null ->
         return (IT (Const Null, BT.Loc))
      | Const (CType_const ct) ->
         return (IT (Const (CType_const ct), BT.CType))
      | Unop (unop, t) ->
         let (arg_bt, ret_bt) = match unop with
         | Not -> (BT.Bool, BT.Bool)
         | BWCLZNoSMT
         | BWCTZNoSMT
         | BWFFSNoSMT -> (BT.Integer, BT.Integer)
         in
         let@ t = check loc arg_bt t in
         return (IT (Unop (unop, t), ret_bt))
      | Binop (arith_op, t, t') ->
         begin match arith_op with
         | Add ->
            let@ t = infer loc t in
            let@ () = ensure_integer_or_real_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            return (IT (Binop (Add, t, t'), IT.bt t))
         | Sub ->
            let@ t = infer loc t in
            let@ () = ensure_integer_or_real_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            return (IT (Binop (Sub, t, t'), IT.bt t))
         | Mul ->
            let@ simp_ctxt = simp_ctxt () in
            let@ t = infer loc t in
            let@ () = ensure_integer_or_real_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            begin match (IT.bt t), (eval simp_ctxt t), (eval simp_ctxt t') with
            | Real, _, _ -> 
               return (IT (Binop (Mul, t, t'), IT.bt t))
            | Integer, simp_t, simp_t' when 
                   Option.is_some (is_const simp_t) 
                   || Option.is_some (is_const simp_t') ->
               return (IT (Binop (Mul, simp_t, simp_t'), IT.bt t))
            | _ ->
               let hint = "Integer multiplication only allowed when one of the arguments is a constant" in
               fail (fun ctxt -> {loc; msg = NIA {it = IT.mul_ (t, t'); ctxt; hint}})
            end
         | MulNoSMT ->
            let@ t = infer loc t in
            let@ () = ensure_integer_or_real_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            return (IT (Binop (MulNoSMT, t, t'), IT.bt t))
         | Div ->
            let@ simp_ctxt = simp_ctxt () in
            let@ t = infer loc t in
            let@ () = ensure_integer_or_real_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            begin match IT.bt t, eval simp_ctxt t' with
            | Real, _ ->
               return (IT (Binop (Div, t, t'), IT.bt t))
            | Integer, simp_t' when Option.is_some (is_const simp_t') ->
               let z = Option.get (is_z simp_t') in
               let@ () = if Z.lt Z.zero z then return ()
                 else fail (fun _ -> {loc; msg = Generic
                   (!^"Divisor " ^^^ IT.pp t' ^^^ !^ "must be positive")}) in
               return (IT (Binop (Div, t, simp_t'), IT.bt t))
            | _ ->
               let hint = "Integer division only allowed when divisor is constant" in
               fail (fun ctxt -> {loc; msg = NIA {it = div_ (t, t'); ctxt; hint}})
            end
         | DivNoSMT ->
            let@ t = infer loc t in
            let@ () = ensure_integer_or_real_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            return (IT (Binop (DivNoSMT, t, t'), IT.bt t))
         | Exp ->
            let@ simp_ctxt = simp_ctxt () in
            let@ t = check loc Integer t in
            let@ t' = check loc Integer t' in
            begin match is_z (eval simp_ctxt t), is_z (eval simp_ctxt t') with
            | Some _, Some z' when Z.lt z' Z.zero ->
               fail (fun ctxt -> {loc; msg = NegativeExponent {it = exp_ (t, t'); ctxt}})
            | Some _, Some z' when not (Z.fits_int32 z') ->
               fail (fun ctxt -> {loc; msg = TooBigExponent {it = exp_ (t, t'); ctxt}})
            | Some z, Some z' ->
               return (IT (Binop (Exp, z_ z, z_ z'), Integer))
            | _ ->
               let hint = "Only exponentiation of two constants is allowed" in
               fail (fun ctxt -> {loc; msg = NIA {it = exp_ (t, t'); ctxt; hint}})
            end
           | ExpNoSMT
           | RemNoSMT
           | ModNoSMT
           | XORNoSMT
           | BWAndNoSMT
           | BWOrNoSMT ->
              let@ t = check loc Integer t in
              let@ t' = check loc Integer t' in
              return (IT (Binop (arith_op, t, t'), Integer))
           | Rem ->
              let@ simp_ctxt = simp_ctxt () in
              let@ t = check loc Integer t in
              let@ t' = check loc Integer t' in
              begin match is_z (eval simp_ctxt t') with
              | None ->
                 let hint = "Only division (rem) by constants is allowed" in
                 fail (fun ctxt -> {loc; msg = NIA {it = rem_ (t, t'); ctxt; hint}})
              | Some z' ->
                 return (IT (Binop (Rem, t, z_ z'), Integer))
              end
           | Mod ->
              let@ simp_ctxt = simp_ctxt () in
              let@ t = check loc Integer t in
              let@ t' = check loc Integer t' in
              begin match is_z (eval simp_ctxt t') with
              | None ->
                 let hint = "Only division (mod) by constants is allowed" in
                 fail (fun ctxt -> {loc; msg = NIA {it = mod_ (t, t'); ctxt; hint}})
              | Some z' ->
                 return (IT (Binop (Mod, t, z_ z'), Integer))
              end
           | LT ->
              let@ t = infer loc t in
              let@ () = ensure_integer_or_real_type loc t in
              let@ t' = check loc (IT.bt t) t' in
              return (IT (Binop (LT, t, t'), BT.Bool))
           | LE ->
              let@ t = infer loc t in
              let@ () = ensure_integer_or_real_type loc t in
              let@ t' = check loc (IT.bt t) t' in
              return (IT (Binop (LE, t, t'), BT.Bool))
           | Min ->
              let@ t = infer loc t in
              let@ () = ensure_integer_or_real_type loc t in
              let@ t' = check loc (IT.bt t) t' in
              return (IT (Binop (Min, t, t'), IT.bt t))
           | Max ->
              let@ t = infer loc t in
              let@ () = ensure_integer_or_real_type loc t in
              let@ t' = check loc (IT.bt t) t' in
              return (IT (Binop (Max, t, t'), IT.bt t))
           | EQ ->
              let@ t = infer loc t in
              let@ t' = check loc (IT.bt t) t' in
              return (IT (Binop (EQ, t,t'),BT.Bool))
           | LTPointer ->
              let@ t = check loc Loc t in
              let@ t' = check loc Loc t' in
              return (IT (Binop (LTPointer, t, t'),BT.Bool))
           | LEPointer ->
              let@ t = check loc Loc t in
              let@ t' = check loc Loc t' in
              return (IT (Binop (LEPointer, t, t'),BT.Bool))
         | SetMember ->
            let@ t = infer loc t in
            let@ t' = check loc (Set (IT.bt t)) t' in
            return (IT (Binop (SetMember, t, t'), BT.Bool))
         | SetUnion ->
            let@ t = infer loc t in
            let@ _itembt = ensure_set_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            return (IT (Binop (SetUnion, t, t'), IT.bt t))
         | SetIntersection ->
            let@ t = infer loc t in
            let@ _itembt = ensure_set_type loc t in
            let@ t' = check loc (IT.bt t) t' in
            return (IT (Binop (SetIntersection, t, t'), IT.bt t))
         | SetDifference ->
            let@ t  = infer loc t in
            let@ itembt = ensure_set_type loc t in
            let@ t' = check loc (Set itembt) t' in
            return (IT (Binop (SetDifference, t, t'), BT.Set itembt))
         | Subset ->
            let@ t = infer loc t in
            let@ itembt = ensure_set_type loc t in
            let@ t' = check loc (Set itembt) t' in
            return (IT (Binop (Subset, t,t'), BT.Bool))
         | And ->
            let@ t = check loc Bool t in
            let@ t' = check loc Bool t' in
            return (IT (Binop (And, t, t'), Bool))
         | Or -> 
            let@ t = check loc Bool t in
            let@ t' = check loc Bool t' in
            return (IT (Binop (Or, t, t'), Bool))
         | Impl ->
            let@ t = check loc Bool t in
            let@ t' = check loc Bool t' in
            return (IT (Binop (Impl, t, t'), Bool))
         end
      | ITE (t,t',t'') ->
         let@ t = check loc Bool t in
         let@ t' = infer loc t' in
         let@ t'' = check loc (IT.bt t') t'' in
         return (IT (ITE (t, t', t''),IT.bt t')) 
      | EachI ((i1, (s, _), i2), t) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, t = IT.alpha_rename (s, BT.Integer) t in *)
         pure begin 
             let@ () = add_l s Integer (loc, lazy (Pp.string "forall-var")) in
             let@ t = check loc Bool t in
             return (IT (EachI ((i1, (s, BT.Integer), i2), t),BT.Bool))
           end
      | Tuple ts ->
         let@ ts = ListM.mapM (infer loc) ts in
         let bts = List.map IT.bt ts in
         return (IT (Tuple ts,BT.Tuple bts))
      | NthTuple (n, t') ->
         let@ t' = infer loc t' in
         let@ item_bt = match IT.bt t' with
           | Tuple bts ->
              begin match List.nth_opt bts n with
              | Some t -> return t
              | None -> 
                 let expected = "tuple with at least " ^ string_of_int n ^ "components" in
                 fail (illtyped_index_term loc t' (Tuple bts) expected)
              end
           | has -> 
              fail (illtyped_index_term loc t' has "tuple")
         in
         return (IT (NthTuple (n, t'),item_bt))
      | Struct (tag, members) ->
         let@ layout = get_struct_decl loc tag in
         let decl_members = Memory.member_types layout in
         let@ () = correct_members loc decl_members members in
         (* "sort" according to declaration *)
         let@ members_sorted = 
           ListM.mapM (fun (id, ct) ->
               let@ t = check loc (BT.of_sct ct) (List.assoc Id.equal id members) in
               return (id, t)
             ) decl_members
         in
         assert (List.length members_sorted = List.length members);
         return (IT (Struct (tag, members_sorted), BT.Struct tag))
      | StructMember (t, member) ->
         let@ t = infer loc t in
         let@ tag = match IT.bt t with
           | Struct tag -> return tag
           | has -> fail (illtyped_index_term loc t has "struct")
         in
         let@ field_ct = get_struct_member_type loc tag member in
         return (IT (StructMember (t, member),BT.of_sct field_ct))
      | StructUpdate ((t, member), v) ->
         let@ t = infer loc t in
         let@ tag = match IT.bt t with
           | Struct tag -> return tag
           | has -> fail (illtyped_index_term loc t has "struct")
         in
         let@ field_ct = get_struct_member_type loc tag member in
         let@ v = check loc (BT.of_sct field_ct) v in
         return (IT (StructUpdate ((t, member), v),BT.Struct tag))
      | Record members ->
         let@ members = no_duplicate_members_sorted loc members in
         let@ members = 
           ListM.mapM (fun (id, t) ->
               let@ t = infer loc t in
               return (id, t)
             ) members
         in
         let member_types = List.map (fun (id, t) -> (id, IT.bt t)) members in
         return (IT (IT.Record members,BT.Record member_types))
      | RecordMember (t, member) ->
         let@ t = infer loc t in
         let@ members = match IT.bt t with
           | Record members -> return members
           | has -> fail (illtyped_index_term loc t has "struct")
         in
         let@ bt = match List.assoc_opt Id.equal member members with
           | Some bt -> return bt
           | None -> 
              let expected = "struct with member " ^ Id.pp_string member in
              fail (illtyped_index_term loc t (IT.bt t) expected)
         in
         return (IT (RecordMember (t, member), bt))
      | RecordUpdate ((t, member), v) ->
         let@ t = infer loc t in
         let@ members = match IT.bt t with
           | Record members -> return members
           | has -> fail (illtyped_index_term loc t has "struct")
         in
         let@ bt = match List.assoc_opt Id.equal member members with
           | Some bt -> return bt
           | None -> 
              let expected = "struct with member " ^ Id.pp_string member in
              fail (illtyped_index_term loc t (IT.bt t) expected)
         in
         let@ v = check loc bt v in
         return (IT (RecordUpdate ((t, member), v),IT.bt t))
       | Cast (cbt, t) ->
          let@ cbt = WBT.is_bt loc cbt in
          let@ t = infer loc t in
          let@ () = match IT.bt t, cbt with
           | Integer, Loc -> return ()
           | Loc, Integer -> return ()
           | Integer, Real -> return ()
           | Real, Integer -> return ()
           | source, target -> 
             let msg = 
               !^"Unsupported cast from" ^^^ BT.pp source
               ^^^ !^"to" ^^^ BT.pp target ^^ dot
             in
             fail (fun _ -> {loc; msg = Generic msg})
          in
          return (IT (Cast (cbt, t), cbt))
       | MemberOffset (tag, member) ->
          let@ _ty = get_struct_member_type loc tag member in
          return (IT (MemberOffset (tag, member),Integer))
       | ArrayOffset (ct, t) ->
          let@ () = WCT.is_ct loc ct in
          let@ t = check loc Integer t in
          return (IT (ArrayOffset (ct, t), Integer))
       | SizeOf ct ->
          let@ () = WCT.is_ct loc ct in
          return (IT (SizeOf ct, Integer))
       | Aligned t ->
          let@ t_t = check loc Loc t.t in
          let@ t_align = check loc Integer t.align in
          return (IT (Aligned {t = t_t; align=t_align},BT.Bool))
       | Representable (ct, t) ->
          let@ () = WCT.is_ct loc ct in
          let@ t = check loc (BT.of_sct ct) t in
          return (IT (Representable (ct, t),BT.Bool))
       | Good (ct, t) ->
          let@ () = WCT.is_ct loc ct in
          let@ t = check loc (BT.of_sct ct) t in
          return (IT (Good (ct, t),BT.Bool))
       | WrapI (ity, t) ->
          let@ () = WCT.is_ct loc (Integer ity) in
          let@ t = check loc Integer t in
          return (IT (WrapI (ity, t), BT.Integer))
       | Nil bt -> 
          let@ bt = WBT.is_bt loc bt in
          return (IT (Nil bt, BT.List bt))
       | Cons (t1,t2) ->
          let@ t1 = infer loc t1 in
          let@ t2 = check loc (List (IT.bt t1)) t2 in
          return (IT (Cons (t1, t2),BT.List (IT.bt t1)))
       | Head t ->
          let@ t = infer loc t in
          let@ bt = ensure_list_type loc t in
          return (IT (Head t,bt))
       | Tail t ->
          let@ t = infer loc t in
          let@ bt = ensure_list_type loc t in
          return (IT (Tail t,BT.List bt))
       | NthList (i, xs, d) ->
          let@ i = check loc Integer i in
          let@ xs = infer loc xs in
          let@ bt = ensure_list_type loc xs in
          let@ d = check loc bt d in
          return (IT (NthList (i, xs, d),bt))
       | ArrayToList (arr, i, len) ->
          let@ i = check loc Integer i in
          let@ len = check loc Integer len in
          let@ arr = infer loc arr in
          let@ (_, bt) = ensure_map_type loc arr in
          return (IT (ArrayToList (arr, i, len), BT.List bt))
      | MapConst (index_bt, t) ->
         let@ index_bt = WBT.is_bt loc index_bt in
         let@ t = infer loc t in
         return (IT (MapConst (index_bt, t), BT.Map (index_bt, IT.bt t)))
      | MapSet (t1, t2, t3) ->
         let@ t1 = infer loc t1 in
         let@ (abt, rbt) = ensure_map_type loc t1 in
         let@ t2 = check loc abt t2 in
         let@ t3 = check loc rbt t3 in
         return (IT (MapSet (t1, t2, t3), IT.bt t1))
      | MapGet (t, arg) -> 
         let@ t = infer loc t in
         let@ (abt, bt) = ensure_map_type loc t in
         let@ arg = check loc abt arg in
         return (IT (MapGet (t, arg),bt))
      | MapDef ((s, abt), body) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, body = IT.alpha_rename (s, abt) body in *)
         let@ abt = WBT.is_bt loc abt in
         pure begin
            let@ () = add_l s abt (loc, lazy (Pp.string "map-def-var")) in
            let@ body = infer loc body in
            return (IT (MapDef ((s, abt), body), Map (abt, IT.bt body)))
            end
      | Apply (name, args) ->
         let@ def = Typing.get_logical_function_def loc name in
         let has_args, expect_args = List.length args, List.length def.args in
         let@ () = ensure_same_argument_number loc `General has_args ~expect:expect_args in
         let@ args = 
           ListM.map2M (fun has_arg (_, def_arg_bt) ->
               check loc def_arg_bt has_arg
             ) args def.args
         in
         return (IT (Apply (name, args), def.return_bt))
      | Let ((name, t1), t2) ->
         let@ t1 = infer loc t1 in
         pure begin
             let@ () = add_l name (IT.bt t1) (loc, lazy (Pp.string "let-var")) in
             let@ () = add_c loc (LC.t_ (IT.def_ name t1)) in
             let@ t2 = infer loc t2 in
             return (IT (Let ((name, t1), t2), IT.bt t2))
           end
      | Constructor (s, args) ->
         let@ info = get_datatype_constr loc s in
         let@ args_annotated = correct_members_sorted_annotated loc info.c_params args in
         let@ args = 
           ListM.mapM (fun (bt', (id', t')) ->
               let@ t' = check loc bt' t' in
               return (id', t')
             ) args_annotated
         in
         return (IT (Constructor (s, args), Datatype info.c_datatype_tag))
      | Match (e, cases) ->
         let@ e = infer loc e in
         let@ rbt, cases = 
           ListM.fold_leftM (fun (rbt, acc) (pat, body) ->
               pure begin
                   let@ pat = check_and_bind_pattern loc (IT.bt e) pat in
                   let@ body = match rbt with
                     | None -> infer loc body 
                     | Some rbt -> check loc rbt body
                   in
                   return (Some (IT.bt body), acc @ [(pat, body)])
                 end
             ) (None, []) cases
         in
         let@ () = cases_complete loc [IT.bt e] (List.map (fun (pat, _) -> [pat]) cases) in
         let@ rbt = match rbt with
           | None -> fail (fun _ -> {loc; msg = Empty_pattern})
           | Some rbt -> return rbt
         in
         return (IT (Match (e, cases), rbt))


    and check loc ls it =
      let@ ls = WLS.is_ls loc ls in
      let@ it = infer loc it in
      if LS.equal ls (IT.bt it) 
      then return it
      else fail (illtyped_index_term loc it (IT.bt it) (Pp.plain (LS.pp ls)))


end








module WRET = struct

  open IndexTerms

  let welltyped loc r = 
    let@ spec_iargs = match RET.predicate_name r with
      | Owned (_ct,_init) ->
         return []
      | PName name -> 
         let@ def = Typing.get_resource_predicate_def loc name in
         return def.iargs
    in
    match r with
    | P p -> 
       let@ pointer = WIT.check loc BT.Loc p.pointer in
       let has_iargs, expect_iargs = List.length p.iargs, List.length spec_iargs in
       (* +1 because of pointer argument *)
       let@ () = ensure_same_argument_number loc `Input (1 + has_iargs) ~expect:(1 + expect_iargs) in
       let@ iargs = ListM.map2M (fun (_, expected) arg -> WIT.check loc expected arg) spec_iargs p.iargs in
       return (RET.P {name = p.name; pointer; iargs})
    | Q p ->
       (* no need to alpha-rename, because context.ml ensures
          there's no name clashes *)
       (* let p = RET.alpha_rename_qpredicate_type p in *)
       let@ pointer = WIT.check loc BT.Loc p.pointer in
       let@ step = WIT.check loc BT.Integer p.step in
       let@ simp_ctxt = simp_ctxt () in
       let@ step = match IT.is_z (Simplify.IndexTerms.eval simp_ctxt step) with
         | Some z ->
           let@ () = if Z.lt Z.zero z then return ()
           else fail (fun _ -> {loc; msg = Generic
             (!^"Iteration step" ^^^ IT.pp p.step ^^^ !^ "must be positive")}) in
           return (IT.z_ z)
         | None ->
           let hint = "Only constant iteration steps are allowed" in
           fail (fun ctxt -> {loc; msg = NIA {it = p.step; ctxt; hint}})
       in
       let@ () = match p.name with
         | (Owned (ct, _init)) ->
           let sz = Memory.size_of_ctype ct in
           if IT.equal step (IT.int_ sz) then return ()
           else fail (fun _ -> {loc; msg = Generic
             (!^"Iteration step" ^^^ IT.pp p.step ^^^ !^ "different to sizeof" ^^^
                 Sctypes.pp ct ^^^ parens (!^ (Int.to_string sz)))})
         | _ -> return ()
       in
       let@ permission, iargs = 
         pure begin 
             let@ () = add_l p.q Integer (loc, lazy (Pp.string "forall-var")) in
             let@ permission = WIT.check loc BT.Bool p.permission in
             let@ provable = provable loc in
             let only_nonnegative_indices =
               LC.forall_ (p.q, Integer) 
                 (impl_ (p.permission, ge_ (sym_ (p.q, BT.Integer), int_ 0)))
             in
             let@ () = match provable only_nonnegative_indices with
               | `True ->
                  return ()
               | `False ->
                  let model = Solver.model () in
                  let msg = "Iterated resource gives ownership to negative indices." in
                  fail (fun ctxt -> {loc; msg = Generic_with_model {err= !^msg; ctxt; model}})
             in
             let has_iargs, expect_iargs = List.length p.iargs, List.length spec_iargs in
             (* +1 because of pointer argument *)
             let@ () = ensure_same_argument_number loc `Input (1 + has_iargs) ~expect:(1 + expect_iargs) in
             let@ iargs = ListM.map2M (fun (_, expected) arg -> WIT.check loc expected arg) spec_iargs p.iargs in
             return (permission, iargs)
           end  
       in
       return (RET.Q {name = p.name; pointer; q = p.q; step; permission; iargs})
end



let oarg_bt_of_pred loc = function
  | RET.Owned (ct,_init) -> 
      return (BT.of_sct ct)
  | RET.PName pn ->
      let@ def = Typing.get_resource_predicate_def loc pn in
      return def.oarg_bt
      

let oarg_bt loc = function
  | RET.P pred -> 
      oarg_bt_of_pred loc pred.name
  | RET.Q pred ->
      let@ item_bt = oarg_bt_of_pred loc pred.name in
      return (BT.make_map_bt Integer item_bt)






module WRS = struct

  let welltyped loc (resource, bt) = 
    let@ resource = WRET.welltyped loc resource in
    let@ bt = WBT.is_bt loc bt in
    let@ oarg_bt = oarg_bt loc resource in
    let@ () = ensure_base_type loc ~expect:oarg_bt bt in
    return (resource, bt)

end




module WLC = struct
  type t = LogicalConstraints.t

  let welltyped loc lc =
    match lc with
    | LC.T it -> 
       let@ it = WIT.check loc BT.Bool it in
       return (LC.T it)
    | LC.Forall ((s, bt), it) ->
       (* no need to alpha-rename, because context.ml ensures
          there's no name clashes *)
       let@ bt = WBT.is_bt loc bt in
       pure begin
           let@ () = add_l s bt (loc, lazy (Pp.string "forall-var")) in
           let@ it = WIT.check loc BT.Bool it in
           return (LC.Forall ((s, bt), it))
       end

end

module WLRT = struct

  module LRT = LogicalReturnTypes
  open LRT
  type t = LogicalReturnTypes.t

  let welltyped loc lrt = 
    let rec aux = function
      | Define ((s, it), info, lrt) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, lrt = LRT.alpha_rename (s, IT.bt it) lrt in *)
         let@ it = WIT.infer loc it in
         let@ () = add_l s (IT.bt it) (loc, lazy (Pp.string "let-var")) in
         let@ () = add_c (fst info) (LC.t_ (IT.def_ s it)) in
         let@ lrt = aux lrt in
         return (Define ((s, it), info, lrt))
      | Resource ((s, (re, re_oa_spec)), info, lrt) -> 
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, lrt = LRT.alpha_rename (s, re_oa_spec) lrt in *)
         let@ (re, re_oa_spec) = WRS.welltyped (fst info) (re, re_oa_spec) in
         let@ () = add_l s re_oa_spec (loc, lazy (Pp.string "let-var")) in
         let@ () = add_r loc (re, O (IT.sym_ (s, re_oa_spec))) in
         let@ lrt = aux lrt in
         return (Resource ((s, (re, re_oa_spec)), info, lrt))
      | Constraint (lc, info, lrt) ->
         let@ lc = WLC.welltyped (fst info) lc in
         let@ () = add_c (fst info) lc in
         let@ lrt = aux lrt in
         return (Constraint (lc, info, lrt))
      | I -> 
         return I
    in
    pure (aux lrt)


end


module WRT = struct

  type t = ReturnTypes.t
  let subst = ReturnTypes.subst
  let pp = ReturnTypes.pp

  let welltyped loc rt = 
    pure begin match rt with 
      | RT.Computational ((name,bt), info, lrt) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let name, lrt = LRT.alpha_rename (name, bt) lrt in *)
         let@ bt = WBT.is_bt (fst info) bt in
         let@ () = add_a name bt (fst info, lazy (Sym.pp name)) in
         let@ lrt = WLRT.welltyped loc lrt in
         return (RT.Computational ((name, bt), info, lrt))
      end

end








module WFalse = struct
  type t = False.t
  let subst = False.subst
  let pp = False.pp
  let welltyped _ False.False = 
    return False.False
end


module WLAT = struct

  let welltyped i_subst i_welltyped kind loc (at : 'i LAT.t) : ('i LAT.t) m = 
    let rec aux = function
      | LAT.Define ((s, it), info, at) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, at = LAT.alpha_rename i_subst (s, IT.bt it) at in *)
         let@ it = WIT.infer loc it in
         let@ () = add_l s (IT.bt it) (loc, lazy (Pp.string "let-var")) in
         let@ () = add_c (fst info) (LC.t_ (IT.def_ s it)) in
         let@ at = aux at in
         return (LAT.Define ((s, it), info, at))
      | LAT.Resource ((s, (re, re_oa_spec)), info, at) -> 
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, at = LAT.alpha_rename i_subst (s, re_oa_spec) at in *)
         let@ (re, re_oa_spec) = WRS.welltyped (fst info) (re, re_oa_spec) in
         let@ () = add_l s re_oa_spec (loc, lazy (Pp.string "let-var")) in
         let@ () = add_r loc (re, O (IT.sym_ (s, re_oa_spec))) in
         let@ at = aux at in
         return (LAT.Resource ((s, (re, re_oa_spec)), info, at))
      | LAT.Constraint (lc, info, at) ->
         let@ lc = WLC.welltyped (fst info) lc in
         let@ () = add_c (fst info) lc in
         let@ at = aux at in
         return (LAT.Constraint (lc, info, at))
      | LAT.I i -> 
         let@ provable = provable loc in
         let@ () = match provable (LC.t_ (IT.bool_ false)) with
           | `True -> fail (fun _ -> {loc; msg = Generic !^("this "^kind^" makes inconsistent assumptions")})
           | `False -> return ()
         in
         let@ i = i_welltyped loc i in
         return (LAT.I i)
    in
    pure (aux at)



end



module WAT = struct

  let welltyped i_subst i_welltyped kind loc (at : 'i AT.t) : ('i AT.t) m = 
    let rec aux = function
      | AT.Computational ((name,bt), info, at) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let name, at = AT.alpha_rename i_subst (name, bt) at in *)
         let@ bt = WBT.is_bt (fst info) bt in
         let@ () = add_a name bt (fst info, lazy (Sym.pp name)) in
         let@ at = aux at in
         return (AT.Computational ((name, bt), info, at))
      | AT.L at ->
         let@ at = WLAT.welltyped i_subst i_welltyped kind loc at in
         return (AT.L at)
    in
    pure (aux at)



end










module WFT = struct 
  let welltyped = WAT.welltyped WRT.subst WRT.welltyped
end

module WLT = struct
  let welltyped = WAT.welltyped WFalse.subst WFalse.welltyped
end

(* module WPackingFT(struct let name_bts = pd.oargs end) = 
   WLAT(WOutputDef.welltyped (pd.oargs)) *)








module WLArgs = struct

  let welltyped 
        (i_welltyped : Loc.t -> 'i -> ('i * 'it) m)
        kind
        loc
        (at : 'i Mu.mu_arguments_l)
      : ('i Mu.mu_arguments_l * 'it LAT.t) m = 
    let rec aux = function
      | Mu.M_Define ((s, it), info, at) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, at = LAT.alpha_rename i_subst (s, IT.bt it) at in *)
         let@ it = WIT.infer loc it in
         let@ () = add_l s (IT.bt it) (loc, lazy (Pp.string "let-var")) in
         let@ () = add_c (fst info) (LC.t_ (IT.def_ s it)) in
         let@ at, typ = aux at in
         return (Mu.M_Define ((s, it), info, at), 
                 LAT.Define ((s, it), info, typ))
      | Mu.M_Resource ((s, (re, re_oa_spec)), info, at) -> 
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let s, at = LAT.alpha_rename i_subst (s, re_oa_spec) at in *)
         let@ (re, re_oa_spec) = WRS.welltyped (fst info) (re, re_oa_spec) in
         let@ () = add_l s re_oa_spec (loc, lazy (Pp.string "let-var")) in
         let@ () = add_r loc (re, O (IT.sym_ (s, re_oa_spec))) in
         let@ at, typ = aux at in
         return (Mu.M_Resource ((s, (re, re_oa_spec)), info, at),
                 LAT.Resource ((s, (re, re_oa_spec)), info, typ))
      | Mu.M_Constraint (lc, info, at) ->
         let@ lc = WLC.welltyped (fst info) lc in
         let@ () = add_c (fst info) lc in
         let@ at, typ = aux at in
         return (Mu.M_Constraint (lc, info, at),
                 LAT.Constraint (lc, info, typ))
      | Mu.M_I i -> 
         let@ provable = provable loc in
         let@ () = match provable (LC.t_ (IT.bool_ false)) with
           | `True -> fail (fun _ -> {loc; msg = Generic !^("this "^kind^" makes inconsistent assumptions")})
           | `False -> return ()
         in
         let@ i, it = i_welltyped loc i in
         return (Mu.M_I i, 
                 LAT.I it)
    in
    pure (aux at)



end



module WArgs = struct

  let welltyped 
        (i_welltyped : Loc.t -> 'i -> ('i * 'it) m) 
        kind 
        loc
        (at : 'i Mu.mu_arguments) 
      : ('i Mu.mu_arguments * 'it AT.t) m = 
    let rec aux = function
      | Mu.M_Computational ((name,bt), info, at) ->
         (* no need to alpha-rename, because context.ml ensures
            there's no name clashes *)
         (* let name, at = AT.alpha_rename i_subst (name, bt) at in *)
         let@ bt = WBT.is_bt (fst info) bt in
         let@ () = add_a name bt (fst info, lazy (Sym.pp name)) in
         let@ at, typ = aux at in
         return (Mu.M_Computational ((name, bt), info, at),
                 AT.Computational ((name, bt), info, typ))
      | Mu.M_L at ->
         let@ at, typ = WLArgs.welltyped i_welltyped kind loc at in
         return (Mu.M_L at, AT.L typ)
    in
    pure (aux at)

end




module WProc = struct 
  let welltyped (loc : Loc.t) (at : _ Mu.mu_proc_args_and_body)
      : (_ Mu.mu_proc_args_and_body * AT.ft) m 
    =
    WArgs.welltyped (fun loc (body, labels, rt) ->
        let@ rt = WRT.welltyped loc rt in
        return ((body, labels, rt), rt)
      ) "function" loc at
end

module WLabel = struct
  open Mu
  let welltyped (loc : Loc.t) (lt : _ mu_expr mu_arguments)
      : (_ mu_expr mu_arguments * AT.lt) m 
    =
    WArgs.welltyped (fun loc body -> 
        return (body, False.False)
      ) "loop/label" loc lt
end


module WRPD = struct

  open ResourcePredicates 

  let welltyped {loc; pointer; iargs; oarg_bt; clauses} = 
    (* no need to alpha-rename, because context.ml ensures
       there's no name clashes *)
    pure begin
        let@ () = add_l pointer BT.Loc (loc, lazy (Pp.string "ptr-var")) in
        let@ iargs = 
          ListM.mapM (fun (s, ls) -> 
              let@ ls = WLS.is_ls loc ls in
              let@ () = add_l s ls (loc, lazy (Pp.string "input-var")) in
              return (s, ls)
            ) iargs 
        in
        let@ oarg_bt = WBT.is_bt loc oarg_bt in
        let@ clauses = match clauses with
          | None -> return None
          | Some clauses ->
             let@ clauses = 
               ListM.fold_leftM (fun acc {loc; guard; packing_ft} ->
                   let@ guard = WIT.check loc BT.Bool guard in
                   let negated_guards = List.map (fun clause -> IT.not_ clause.guard) acc in
                   pure begin 
                       let@ () = add_c loc (LC.t_ guard) in
                       let@ () = add_c loc (LC.t_ (IT.and_ negated_guards)) in
                       let@ packing_ft = 
                         WLAT.welltyped IT.subst (fun loc it -> WIT.check loc oarg_bt it)
                           "clause" loc packing_ft
                       in
                       return (acc @ [{loc; guard; packing_ft}])
                     end
                 ) [] clauses
             in
             return (Some clauses)
        in
        return {loc; pointer; iargs; oarg_bt; clauses}
      end

end



module WLFD = struct

  open LogicalFunctions

  let welltyped ({loc; args; return_bt; emit_coq; definition} : LogicalFunctions.definition) = 
    (* no need to alpha-rename, because context.ml ensures
       there's no name clashes *)
    pure begin
        let@ args = 
          ListM.mapM (fun (s,ls) -> 
              let@ ls = WLS.is_ls loc ls in
              let@ () = add_l s ls (loc, lazy (Pp.string "arg-var")) in
              return (s, ls)
            ) args 
        in
        let@ return_bt = WBT.is_bt loc return_bt in
        let@ definition = match definition with
          | Def body -> 
             let@ body = WIT.check loc return_bt body in
             return (Def body)
          | Rec_Def body -> 
             let@ body = WIT.check loc return_bt body in
             return (Rec_Def body)
          | Uninterp -> 
             return Uninterp
        in
        return {loc; args; return_bt; emit_coq; definition}
      end

end




module WLemma = struct

  let welltyped loc lemma_s lemma_typ = 
    WAT.welltyped LRT.subst WLRT.welltyped "lemma" loc lemma_typ

end


module WDT = struct

  open Mu

  let welltyped (dt_name, {loc; cases}) =
    let@ _ = 
      (* all argument members disjoint *)
      ListM.fold_leftM (fun already (id,_) ->
          if IdSet.mem id already 
          then fail (fun _ -> {loc; msg = Duplicate_member id})
          else return (IdSet.add id already)
        ) IdSet.empty (List.concat_map snd cases)
    in
    let@ cases = 
      ListM.mapM (fun (c, args) ->
          let@ args = 
            ListM.mapM (fun (id,bt) -> 
                let@ bt = WBT.is_bt loc bt in
                return (id, bt)
              ) (List.sort compare_by_member_id args)
          in
          return (c, args)
        ) cases
    in
    return (dt_name, {loc; cases})

end
