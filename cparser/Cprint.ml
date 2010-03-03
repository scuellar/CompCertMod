(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the GNU General Public License as published by  *)
(*  the Free Software Foundation, either version 2 of the License, or  *)
(*  (at your option) any later version.  This file is also distributed *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(* Pretty-printer for C abstract syntax *)

open Format
open C

let print_idents_in_full = ref false

let print_line_numbers = ref false

let location pp (file, lineno) =
  if !print_line_numbers && lineno >= 0 then
    fprintf pp "# %d \"%s\"@ " lineno file

let ident pp i =
  if !print_idents_in_full
  then fprintf pp "%s$%d" i.name i.stamp
  else fprintf pp "%s" i.name

let attribute pp = function
  | AConst -> fprintf pp "const"
  | AVolatile -> fprintf pp "volatile"
  | ARestrict -> fprintf pp "restrict"

let attributes pp = function
  | [] -> ()
  | al -> List.iter (fun a -> fprintf pp " %a" attribute a) al

let name_of_ikind = function
  | IBool -> "_Bool"
  | IChar -> "char"
  | ISChar -> "signed char"
  | IUChar -> "unsigned char"
  | IInt -> "int"
  | IUInt -> "unsigned int"
  | IShort -> "short"
  | IUShort -> "unsigned short"
  | ILong -> "long"
  | IULong -> "unsigned long"
  | ILongLong -> "long long"
  | IULongLong -> "unsigned long long"

let name_of_fkind = function
  | FFloat -> "float"
  | FDouble -> "double"
  | FLongDouble -> "long double"

let rec dcl pp ty n =
  match ty with
  | TVoid a ->
      fprintf pp "void%a%t" attributes a n
  | TInt(k, a) ->
      fprintf pp "%s%a%t" (name_of_ikind k) attributes a n
  | TFloat(k, a) ->
      fprintf pp "%s%a%t" (name_of_fkind k) attributes a n
  | TPtr(t, a) ->
      let n' pp =
        match t with
        | TFun _ | TArray _ -> fprintf pp " (*%a%t)" attributes a n
        | _ -> fprintf pp " *%a%t" attributes a n in
      dcl pp t n'
  | TArray(t, sz, a) ->
      let n' pp =
        begin match a with
        | [] -> n pp
        | _  -> fprintf pp " (%a%t)" attributes a n
        end;
        begin match sz with
        | None -> fprintf pp "[]"
        | Some i -> fprintf pp "[%Ld]" i
        end in
      dcl pp t n'
  | TFun(tres, args, vararg, a) ->
      let param (id, ty) =
        dcl pp ty
          (fun pp -> fprintf pp " %a" ident id) in
      let n' pp =
        begin match a with
        | [] -> n pp
        | _  -> fprintf pp " (%a%t)" attributes a n
        end;
        fprintf pp "(@[<hov 0>";
        begin match args with
        | None -> ()
        | Some [] -> if vararg then fprintf pp "..." else fprintf pp "void"
        | Some (a1 :: al) ->
            param a1;
            List.iter (fun a -> fprintf pp ",@ "; param a) al;
            if vararg then fprintf pp ",@ ..."
        end;
        fprintf pp "@])" in
      dcl pp tres n'
  | TNamed(id, a) ->
      fprintf pp "%a%a%t" ident id attributes a n
  | TStruct(id, a) ->
      fprintf pp "struct %a%a%t" ident id attributes a n
  | TUnion(id, a) ->
      fprintf pp "union %a%a%t" ident id attributes a n

let typ pp ty =
  dcl pp ty (fun _ -> ())

let const pp = function
  | CInt(v, ik, s) ->
      if s <> "" then
        fprintf pp "%s" s
      else begin
        fprintf pp "%Ld" v;
        match ik with
        | IULongLong -> fprintf pp "ULL"
        | ILongLong -> fprintf pp "LL"
        | IULong -> fprintf pp "UL"
        | ILong -> fprintf pp "L"
        | IUInt -> fprintf pp "U"
        | _ -> ()
      end
  | CFloat(v, fk, s) ->
      if s <> "" then
        fprintf pp "%s" s
      else begin
        fprintf pp "%.18g" v;
        match fk with
        | FFloat -> fprintf pp "F"
        | FLongDouble -> fprintf pp "L"
        | _ -> ()
      end
  | CStr s ->
      fprintf pp "\"";
      for i = 0 to String.length s - 1 do
        match s.[i] with
        | '\009' -> fprintf pp "\\t"
        | '\010' -> fprintf pp "\\n"
        | '\013' -> fprintf pp "\\r"
        | '\"'   -> fprintf pp "\\\""
        | '\\'   -> fprintf pp "\\\\"
        | c ->
            if c >= ' ' && c <= '~'
            then fprintf pp "%c" c
            else fprintf pp "\\%03o" (Char.code c)
      done;
      fprintf pp "\""
  | CWStr l ->
      fprintf pp "L\"";
      List.iter
        (fun c ->
          if c >= 32L && c <= 126L && c <> 34L && c <>92L
          then fprintf pp "%c" (Char.chr (Int64.to_int c))
          else fprintf pp "\" \"\\x%02Lx\" \"" c)
        l;      
      fprintf pp "\""
  | CEnum(id, v) ->
      ident pp id

type associativity = LtoR | RtoL | NA

let precedence = function               (* H&S section 7.2 *)
  | EConst _ -> (16, NA)
  | ESizeof _ -> (15, RtoL)
  | EVar _ -> (16, NA)
  | EBinop(Oindex, _, _, _) -> (16, LtoR)
  | ECall _ -> (16, LtoR)
  | EUnop((Odot _|Oarrow _), _) -> (16, LtoR)
  | EUnop((Opostincr|Opostdecr), _) -> (16, LtoR)
  | EUnop((Opreincr|Opredecr|Onot|Olognot|Ominus|Oplus|Oaddrof|Oderef), _) -> (15, RtoL)
  | ECast _ -> (14, RtoL)
  | EBinop((Omul|Odiv|Omod), _, _, _) -> (13, LtoR)
  | EBinop((Oadd|Osub), _, _, _) -> (12, LtoR)
  | EBinop((Oshl|Oshr), _, _, _) -> (11, LtoR)
  | EBinop((Olt|Ogt|Ole|Oge), _, _, _) -> (10, LtoR)
  | EBinop((Oeq|One), _, _, _) -> (9, LtoR)
  | EBinop(Oand, _, _, _) -> (8, LtoR)
  | EBinop(Oxor, _, _, _) -> (7, LtoR)
  | EBinop(Oor, _, _, _) -> (6, LtoR)
  | EBinop(Ologand, _, _, _) -> (5, LtoR)
  | EBinop(Ologor, _, _, _) -> (4, LtoR)
  | EConditional _ -> (3, RtoL)
  | EBinop((Oassign|Oadd_assign|Osub_assign|Omul_assign|Odiv_assign|Omod_assign|Oand_assign|Oor_assign|Oxor_assign|Oshl_assign|Oshr_assign), _, _, _) -> (2, RtoL)
  | EBinop(Ocomma, _, _, _) -> (1, LtoR)

let rec exp pp (prec, a) =
  let (prec', assoc) = precedence a.edesc in
  let (prec1, prec2) =
    if assoc = LtoR
    then (prec', prec' + 1)
    else (prec' + 1, prec') in
  if prec' < prec 
  then fprintf pp "@[<hov 2>("
  else fprintf pp "@[<hov 2>";
  begin match a.edesc with
  | EConst cst -> const pp cst
  | EVar id -> ident pp id
  | ESizeof ty -> fprintf pp "sizeof(%a)" typ ty
  | EUnop(Ominus, a1) ->
      fprintf pp "-%a" exp (prec', a1)
  | EUnop(Oplus, a1) ->
      fprintf pp "+%a" exp (prec', a1)
  | EUnop(Olognot, a1) ->
      fprintf pp "!%a" exp (prec', a1)
  | EUnop(Onot, a1) ->
      fprintf pp "~%a" exp (prec', a1)
  | EUnop(Oderef, a1) ->
      fprintf pp "*%a" exp (prec', a1)
  | EUnop(Oaddrof, a1) ->
      fprintf pp "&%a" exp (prec', a1)
  | EUnop(Opreincr, a1) ->
      fprintf pp "++%a" exp (prec', a1)
  | EUnop(Opredecr, a1) ->
      fprintf pp "--%a" exp (prec', a1)
  | EUnop(Opostincr, a1) ->
      fprintf pp "%a++" exp (prec', a1)
  | EUnop(Opostdecr, a1) ->
      fprintf pp "%a--" exp (prec', a1)
  | EUnop(Odot s, a1) ->
      fprintf pp "%a.%s" exp (prec', a1)s
  | EUnop(Oarrow s, a1) ->
      fprintf pp "%a->%s" exp (prec', a1)s
  | EBinop(Oadd, a1, a2, _) ->
      fprintf pp "%a@ + %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Osub, a1, a2, _) ->
      fprintf pp "%a@ - %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Omul, a1, a2, _) ->
      fprintf pp "%a@ * %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Odiv, a1, a2, _) ->
      fprintf pp "%a@ / %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Omod, a1, a2, _) ->
      fprintf pp "%a@ %% %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oand, a1, a2, _) ->
      fprintf pp "%a@ & %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oor, a1, a2, _) ->
      fprintf pp "%a@ | %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oxor, a1, a2, _) ->
      fprintf pp "%a@ ^ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oshl, a1, a2, _) ->
      fprintf pp "%a@ << %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oshr, a1, a2, _) ->
      fprintf pp "%a@ >> %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oeq, a1, a2, _) ->
      fprintf pp "%a@ == %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(One, a1, a2, _) ->
      fprintf pp "%a@ != %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Olt, a1, a2, _) ->
      fprintf pp "%a@ < %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Ogt, a1, a2, _) ->
      fprintf pp "%a@ > %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Ole, a1, a2, _) ->
      fprintf pp "%a@ <= %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oge, a1, a2, _) ->
      fprintf pp "%a@ >= %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oindex, a1, a2, _) ->
      fprintf pp "%a[%a]" exp (prec1, a1) exp (0, a2)
  | EBinop(Oassign, a1, a2, _) ->
      fprintf pp "%a =@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oadd_assign, a1, a2, _) ->
      fprintf pp "%a +=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Osub_assign, a1, a2, _) ->
      fprintf pp "%a -=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Omul_assign, a1, a2, _) ->
      fprintf pp "%a *=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Odiv_assign, a1, a2, _) ->
      fprintf pp "%a /=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Omod_assign, a1, a2, _) ->
      fprintf pp "%a %%=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oand_assign, a1, a2, _) ->
      fprintf pp "%a &=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oor_assign, a1, a2, _) ->
      fprintf pp "%a |=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oxor_assign, a1, a2, _) ->
      fprintf pp "%a ^=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oshl_assign, a1, a2, _) ->
      fprintf pp "%a <<=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Oshr_assign, a1, a2, _) ->
      fprintf pp "%a >>=@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Ocomma, a1, a2, _) ->
      fprintf pp "%a,@ %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Ologand, a1, a2, _) ->
      fprintf pp "%a@ && %a" exp (prec1, a1) exp (prec2, a2)
  | EBinop(Ologor, a1, a2, _) ->
      fprintf pp "%a@ || %a" exp (prec1, a1) exp (prec2, a2)
  | EConditional(a1, a2, a3) ->
      fprintf pp "%a@ ? %a@ : %a" exp (4, a1) exp (4, a2) exp (4, a3)
  | ECast(ty, a1) ->
      fprintf pp "(%a) %a" typ ty exp (prec', a1)
  | ECall({edesc = EVar {name = "__builtin_va_start"}},
          [a1; {edesc = EUnop(Oaddrof, a2)}]) ->
      fprintf pp "__builtin_va_start@[<hov 1>(%a,@ %a)@]"
              exp (2, a1) exp (2, a2)
  | ECall({edesc = EVar {name = "__builtin_va_arg"}},
          [a1; {edesc = ESizeof ty}]) ->
      fprintf pp "__builtin_va_arg@[<hov 1>(%a,@ %a)@]"
              exp (2, a1) typ ty
  | ECall(a1, al) ->
      fprintf pp "%a@[<hov 1>(" exp (prec', a1);
      begin match al with
      | [] -> ()
      | a1 :: al ->
          fprintf pp "%a" exp (2, a1); 
          List.iter (fun a -> fprintf pp ",@ %a" exp (2, a)) al
      end;
      fprintf pp ")@]"
  end;
  if prec' < prec then fprintf pp ")@]" else fprintf pp "@]"

let rec init pp = function
  | Init_single e ->
      exp pp (2, e)
  | Init_array il ->
      fprintf pp "@[<hov 1>{";
      List.iter (fun i -> fprintf pp "%a,@ " init i) il;
      fprintf pp "}@]"
  | Init_struct(id, il) ->
      fprintf pp "@[<hov 1>{";
      List.iter (fun (fld, i) -> fprintf pp "%a,@ " init i) il;
      fprintf pp "}@]"
  | Init_union(id, fld, i) ->
      fprintf pp "@[<hov 1>{%a}@]" init i

let simple_decl pp (id, ty) =
  dcl pp ty (fun pp -> fprintf pp " %a" ident id)

let storage pp = function
  | Storage_default -> ()
  | Storage_extern -> fprintf pp "extern "
  | Storage_static -> fprintf pp "static "
  | Storage_register -> fprintf pp "register "

let full_decl pp (sto, id, ty, int) =
  fprintf pp "@[<hov 2>%a" storage sto;
  dcl pp ty (fun pp -> fprintf pp " %a" ident id);
  begin match int with
  | None -> ()
  | Some i -> fprintf pp " =@ %a" init i
  end;
  fprintf pp ";@]"

exception Not_expr

let rec exp_of_stmt s =
  match s.sdesc with
  | Sdo e -> e
  | Sseq(s1, s2) -> 
      {edesc = EBinop(Ocomma, exp_of_stmt s1, exp_of_stmt s2, TVoid []);
       etyp = TVoid []}
  | Sif(e, s1, s2) ->
      {edesc = EConditional(e, exp_of_stmt s1, exp_of_stmt s2);
       etyp = TVoid []}
  | _ ->
      raise Not_expr

let rec stmt pp s =
  location pp s.sloc;
  match s.sdesc with
  | Sskip ->
      fprintf pp "/*skip*/;"
  | Sdo e ->
      fprintf pp "%a;" exp (0, e)
  | Sseq(s1, s2) ->
      fprintf pp "%a@ %a" stmt s1 stmt s2
  | Sif(e, s1, {sdesc = Sskip}) ->
      fprintf pp "@[<v 2>if (%a) {@ %a@;<0 -2>}@]"
              exp (0, e) stmt_block s1
  | Sif(e, {sdesc = Sskip}, s2) ->
      let not_e = {edesc = EUnop(Olognot, e); etyp = TInt(IInt, [])} in
      fprintf pp "@[<v 2>if (%a) {@ %a@;<0 -2>}@]"
              exp (0, not_e) stmt_block s2
  | Sif(e, s1, s2) ->
      fprintf pp  "@[<v 2>if (%a) {@ %a@;<0 -2>} else {@ %a@;<0 -2>}@]"
              exp (0, e) stmt_block s1 stmt_block s2
  | Swhile(e, s1) ->
      fprintf pp "@[<v 2>while (%a) {@ %a@;<0 -2>}@]"
              exp (0, e) stmt_block s1
  | Sdowhile(s1, e) ->
      fprintf pp "@[<v 2>do {@ %a@;<0 -2>} while(%a);@]"
              stmt_block s1 exp (0, e)
  | Sfor(e1, e2, e3, s1) ->
      fprintf pp "@[<v 2>for (@[<hv 0>%a;@ %a;@ %a) {@]@ %a@;<0 -2>}@]"
              opt_exp e1
              exp (0, e2)
              opt_exp e3
              stmt_block s1
  | Sbreak ->
      fprintf pp "break;"
  | Scontinue ->
      fprintf pp "continue;"
  | Sswitch(e, s1) ->
      fprintf pp "@[<v 2>switch (%a) {@ %a@;<0 -2>}@]"
              exp (0, e)
              stmt_block s1
  | Slabeled(lbl, s1) ->
      fprintf pp "%a:@ %a" slabel lbl stmt s1
  | Sgoto lbl ->
      fprintf pp "goto %s;" lbl
  | Sreturn None ->
      fprintf pp "return;"
  | Sreturn (Some e) ->
      fprintf pp "return %a;" exp (0, e)
  | Sblock sl ->
      fprintf pp "@[<v 2>{@ %a@;<0 -2>}@]" stmt_block s
  | Sdecl d ->
      full_decl pp d

and slabel pp = function
  | Slabel s ->
      fprintf pp "%s" s
  | Scase e ->
      fprintf pp "case %a" exp (0, e)
  | Sdefault ->
      fprintf pp "default"

and stmt_block pp s =
  match s.sdesc with
  | Sblock [] -> ()
  | Sblock (s1 :: sl) ->
      stmt pp s1;
      List.iter (fun s -> fprintf pp "@ %a" stmt s) sl
  | _ ->
      stmt pp s

and opt_exp pp s =
  if s.sdesc = Sskip then fprintf pp "/*nothing*/" else
    try
      exp pp (0, exp_of_stmt s)
    with Not_expr ->
      fprintf pp "@[<v 3>({ %a })@]" stmt s

let fundef pp f =
  fprintf pp "@[<hov 2>%a" storage f.fd_storage;
  simple_decl pp (f.fd_name, TFun(f.fd_ret, Some f.fd_params, f.fd_vararg, []));
  fprintf pp "@]@ @[<v 2>{@ ";
  List.iter (fun d -> fprintf pp "%a@ " full_decl d) f.fd_locals;
  stmt_block pp f.fd_body;
  fprintf pp "@;<0 -2>}@]@ @ "

let field pp f =
  simple_decl pp ({name = f.fld_name; stamp = 0}, f.fld_typ);
  match f.fld_bitfield with
  | None -> ()
  | Some n -> fprintf pp " : %d" n

let globdecl pp g =
  location pp g.gloc;
  match g.gdesc with
  | Gdecl d ->
      fprintf pp "%a@ @ " full_decl d
  | Gfundef f ->
      fundef pp f
  | Gcompositedecl(kind, id) ->
      fprintf pp "%s %a;@ @ "
        (match kind with Struct -> "struct" | Union -> "union")
        ident id
  | Gcompositedef(kind, id, flds) ->
      fprintf pp "@[<v 2>%s %a {"
        (match kind with Struct -> "struct" | Union -> "union")
        ident id;
      List.iter (fun fld -> fprintf pp "@ %a;" field fld) flds;
      fprintf pp "@;<0 -2>};@]@ @ "
  | Gtypedef(id, ty) ->
      fprintf pp "@[<hov 2>typedef %a;@]@ @ " simple_decl (id, ty)
  | Genumdef(id, fields) ->
      fprintf pp "@[<v 2>enum %a {" ident id;
      List.iter
        (fun (name, opt_e) ->
           fprintf pp "@ %a" ident name;
           begin match opt_e with
           | None -> ()
           | Some e -> fprintf pp " = %a" exp (0, e)
           end;
           fprintf pp ",")
         fields;
       fprintf pp "@;<0 -2>};@]@ @ "
  | Gpragma s ->
       fprintf pp "#pragma %s@ @ " s

let program pp prog =
  fprintf pp "@[<v 0>";
  List.iter (globdecl pp) prog;
  fprintf pp "@]@."
