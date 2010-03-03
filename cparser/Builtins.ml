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

(* Compiler built-ins *)

open C
open Cutil

(* Code adapted from CIL *)

let voidType = TVoid []
let charType = TInt(IChar, [])
let intType = TInt(IInt, [])
let uintType = TInt(IUInt, [])
let longType = TInt(ILong, [])
let ulongType = TInt(IULong, [])
let ulongLongType = TInt(IULongLong, [])
let floatType = TFloat(FFloat, [])
let doubleType = TFloat(FDouble, [])
let longDoubleType = TFloat (FLongDouble, [])
let voidPtrType = TPtr(TVoid [], [])
let voidConstPtrType = TPtr(TVoid [AConst], [])
let charPtrType = TPtr(TInt(IChar, []), [])
let charConstPtrType = TPtr(TInt(IChar, [AConst]), [])
let intPtrType = TPtr(TInt(IInt, []), [])
let sizeType = TInt(size_t_ikind, [])

let gcc_builtin_types = [
  "__builtin_va_list", voidPtrType
]

let gcc_builtin_values = [
  "__builtin___fprintf_chk",  (intType, [ voidPtrType; intType; charConstPtrType ], true) (* first argument is really FILE*, not void*, but we don't want to build in the definition for FILE *);
  "__builtin___memcpy_chk",  (voidPtrType, [ voidPtrType; voidConstPtrType; sizeType; sizeType ], false);
  "__builtin___memmove_chk",  (voidPtrType, [ voidPtrType; voidConstPtrType; sizeType; sizeType ], false);
  "__builtin___mempcpy_chk",  (voidPtrType, [ voidPtrType; voidConstPtrType; sizeType; sizeType ], false);
  "__builtin___memset_chk",  (voidPtrType, [ voidPtrType; intType; sizeType; sizeType ], false);
  "__builtin___printf_chk",  (intType, [ intType; charConstPtrType ], true);
  "__builtin___snprintf_chk",  (intType, [ charPtrType; sizeType; intType; sizeType; charConstPtrType ], true);
  "__builtin___sprintf_chk",  (intType, [ charPtrType; intType; sizeType; charConstPtrType ], true);
  "__builtin___stpcpy_chk",  (charPtrType, [ charPtrType; charConstPtrType; sizeType ], false);
  "__builtin___strcat_chk",  (charPtrType, [ charPtrType; charConstPtrType; sizeType ], false);
  "__builtin___strcpy_chk",  (charPtrType, [ charPtrType; charConstPtrType; sizeType ], false);
  "__builtin___strncat_chk",  (charPtrType, [ charPtrType; charConstPtrType; sizeType; sizeType ], false);
  "__builtin___strncpy_chk",  (charPtrType, [ charPtrType; charConstPtrType; sizeType; sizeType ], false);
  "__builtin___vfprintf_chk",  (intType, [ voidPtrType; intType; charConstPtrType; voidPtrType ], false) (* first argument is really FILE*, not void*, but we don't want to build in the definition for FILE *);
  "__builtin___vprintf_chk",  (intType, [ intType; charConstPtrType; voidPtrType ], false);
  "__builtin___vsnprintf_chk",  (intType, [ charPtrType; sizeType; intType; sizeType; charConstPtrType; voidPtrType ], false);
  "__builtin___vsprintf_chk",  (intType, [ charPtrType; intType; sizeType; charConstPtrType; voidPtrType ], false);

  "__builtin_acos",  (doubleType, [ doubleType ], false);
  "__builtin_acosf",  (floatType, [ floatType ], false);
  "__builtin_acosl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_alloca",  (voidPtrType, [ uintType ], false);
  
  "__builtin_asin",  (doubleType, [ doubleType ], false);
  "__builtin_asinf",  (floatType, [ floatType ], false);
  "__builtin_asinl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_atan",  (doubleType, [ doubleType ], false);
  "__builtin_atanf",  (floatType, [ floatType ], false);
  "__builtin_atanl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_atan2",  (doubleType, [ doubleType; doubleType ], false);
  "__builtin_atan2f",  (floatType, [ floatType; floatType ], false);
  "__builtin_atan2l",  (longDoubleType, [ longDoubleType; 
                                                longDoubleType ], false);

  "__builtin_ceil",  (doubleType, [ doubleType ], false);
  "__builtin_ceilf",  (floatType, [ floatType ], false);
  "__builtin_ceill",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_cos",  (doubleType, [ doubleType ], false);
  "__builtin_cosf",  (floatType, [ floatType ], false);
  "__builtin_cosl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_cosh",  (doubleType, [ doubleType ], false);
  "__builtin_coshf",  (floatType, [ floatType ], false);
  "__builtin_coshl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_clz",  (intType, [ uintType ], false);
  "__builtin_clzl",  (intType, [ ulongType ], false);
  "__builtin_clzll",  (intType, [ ulongLongType ], false);
  "__builtin_constant_p",  (intType, [ intType ], false);
  "__builtin_ctz",  (intType, [ uintType ], false);
  "__builtin_ctzl",  (intType, [ ulongType ], false);
  "__builtin_ctzll",  (intType, [ ulongLongType ], false);

  "__builtin_exp",  (doubleType, [ doubleType ], false);
  "__builtin_expf",  (floatType, [ floatType ], false);
  "__builtin_expl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_expect",  (longType, [ longType; longType ], false);

  "__builtin_fabs",  (doubleType, [ doubleType ], false);
  "__builtin_fabsf",  (floatType, [ floatType ], false);
  "__builtin_fabsl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_ffs",  (intType, [ uintType ], false);
  "__builtin_ffsl",  (intType, [ ulongType ], false);
  "__builtin_ffsll",  (intType, [ ulongLongType ], false);
  "__builtin_frame_address",  (voidPtrType, [ uintType ], false);

  "__builtin_floor",  (doubleType, [ doubleType ], false);
  "__builtin_floorf",  (floatType, [ floatType ], false);
  "__builtin_floorl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_huge_val",  (doubleType, [], false);
  "__builtin_huge_valf",  (floatType, [], false);
  "__builtin_huge_vall",  (longDoubleType, [], false);
  "__builtin_inf",  (doubleType, [], false);
  "__builtin_inff",  (floatType, [], false);
  "__builtin_infl",  (longDoubleType, [], false);
  "__builtin_memcpy",  (voidPtrType, [ voidPtrType; voidConstPtrType; uintType ], false);
  "__builtin_mempcpy",  (voidPtrType, [ voidPtrType; voidConstPtrType; sizeType ], false);

  "__builtin_fmod",  (doubleType, [ doubleType ], false);
  "__builtin_fmodf",  (floatType, [ floatType ], false);
  "__builtin_fmodl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_frexp",  (doubleType, [ doubleType; intPtrType ], false);
  "__builtin_frexpf",  (floatType, [ floatType; intPtrType  ], false);
  "__builtin_frexpl",  (longDoubleType, [ longDoubleType; 
                                                intPtrType  ], false);

  "__builtin_ldexp",  (doubleType, [ doubleType; intType ], false);
  "__builtin_ldexpf",  (floatType, [ floatType; intType  ], false);
  "__builtin_ldexpl",  (longDoubleType, [ longDoubleType; 
                                                intType  ], false);

  "__builtin_log",  (doubleType, [ doubleType ], false);
  "__builtin_logf",  (floatType, [ floatType ], false);
  "__builtin_logl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_log10",  (doubleType, [ doubleType ], false);
  "__builtin_log10f",  (floatType, [ floatType ], false);
  "__builtin_log10l",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_modff",  (floatType, [ floatType; 
                                          TPtr(floatType,[]) ], false);
  "__builtin_modfl",  (longDoubleType, [ longDoubleType; 
                                               TPtr(longDoubleType, []) ], 
                             false);

  "__builtin_nan",  (doubleType, [ charConstPtrType ], false);
  "__builtin_nanf",  (floatType, [ charConstPtrType ], false);
  "__builtin_nanl",  (longDoubleType, [ charConstPtrType ], false);
  "__builtin_nans",  (doubleType, [ charConstPtrType ], false);
  "__builtin_nansf",  (floatType, [ charConstPtrType ], false);
  "__builtin_nansl",  (longDoubleType, [ charConstPtrType ], false);
  "__builtin_next_arg",  (voidPtrType, [], false);
  "__builtin_object_size",  (sizeType, [ voidPtrType; intType ], false);

  "__builtin_parity",  (intType, [ uintType ], false);
  "__builtin_parityl",  (intType, [ ulongType ], false);
  "__builtin_parityll",  (intType, [ ulongLongType ], false);

  "__builtin_popcount",  (intType, [ uintType ], false);
  "__builtin_popcountl",  (intType, [ ulongType ], false);
  "__builtin_popcountll",  (intType, [ ulongLongType ], false);

  "__builtin_powi",  (doubleType, [ doubleType; intType ], false);
  "__builtin_powif",  (floatType, [ floatType; intType ], false);
  "__builtin_powil",  (longDoubleType, [ longDoubleType; intType ], false);
  "__builtin_prefetch",  (voidType, [ voidConstPtrType ], true);
  "__builtin_return",  (voidType, [ voidConstPtrType ], false);
  "__builtin_return_address",  (voidPtrType, [ uintType ], false);

  "__builtin_sin",  (doubleType, [ doubleType ], false);
  "__builtin_sinf",  (floatType, [ floatType ], false);
  "__builtin_sinl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_sinh",  (doubleType, [ doubleType ], false);
  "__builtin_sinhf",  (floatType, [ floatType ], false);
  "__builtin_sinhl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_sqrt",  (doubleType, [ doubleType ], false);
  "__builtin_sqrtf",  (floatType, [ floatType ], false);
  "__builtin_sqrtl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_stpcpy",  (charPtrType, [ charPtrType; charConstPtrType ], false);
  "__builtin_strchr",  (charPtrType, [ charPtrType; charType ], false);
  "__builtin_strcmp",  (intType, [ charConstPtrType; charConstPtrType ], false);
  "__builtin_strcpy",  (charPtrType, [ charPtrType; charConstPtrType ], false);
  "__builtin_strcspn",  (uintType, [ charConstPtrType; charConstPtrType ], false);
  "__builtin_strncat",  (charPtrType, [ charPtrType; charConstPtrType; sizeType ], false);
  "__builtin_strncmp",  (intType, [ charConstPtrType; charConstPtrType; sizeType ], false);
  "__builtin_strncpy",  (charPtrType, [ charPtrType; charConstPtrType; sizeType ], false);
  "__builtin_strspn",  (intType, [ charConstPtrType; charConstPtrType ], false);
  "__builtin_strpbrk",  (charPtrType, [ charConstPtrType; charConstPtrType ], false);
  (* When we parse builtin_types_compatible_p, we change its interface *)
  "__builtin_types_compatible_p", 
                              (intType, [ uintType; (* Sizeof the type *)
                                          uintType  (* Sizeof the type *) ],
                               false);
  "__builtin_tan",  (doubleType, [ doubleType ], false);
  "__builtin_tanf",  (floatType, [ floatType ], false);
  "__builtin_tanl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_tanh",  (doubleType, [ doubleType ], false);
  "__builtin_tanhf",  (floatType, [ floatType ], false);
  "__builtin_tanhl",  (longDoubleType, [ longDoubleType ], false);

  "__builtin_va_end",  (voidType, [ voidPtrType ], false);
  "__builtin_varargs_start",  
    (voidType, [ voidPtrType ], false);
  (* When we elaborate builtin_stdarg_start/builtin_va_start,
     second argument is passed by address *)
  "__builtin_va_start",  (voidType, [ voidPtrType; voidPtrType ], false);
  "__builtin_stdarg_start",  (voidType, [ voidPtrType ], false);
  (* When we parse builtin_va_arg, type argument becomes sizeof type *)
  "__builtin_va_arg",  (voidType, [ voidPtrType; sizeType ], false);
  "__builtin_va_copy",  (voidType, [ voidPtrType;
                                           voidPtrType ],
                              false)
]

let (builtin_env, builtin_idents) =
  let env = ref Env.empty
  and ids = ref [] in
  List.iter
    (fun (s, ty) ->
      let (id, env') = Env.enter_typedef !env s ty in
      env := env';
      ids := id :: !ids)
    gcc_builtin_types;
  List.iter
    (fun (s, (res, args, va)) ->
      let ty =
        TFun(res,
             Some (List.map (fun ty -> (Env.fresh_ident "", ty)) args),
             va, []) in
      let (id, env') = Env.enter_ident !env s Storage_extern ty in
      env := env';
      ids := id :: !ids)
    gcc_builtin_values;
  (!env, List.rev !ids)
