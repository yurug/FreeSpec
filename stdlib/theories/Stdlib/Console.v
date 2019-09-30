(* FreeSpec
 * Copyright (C) 2018–2019 ANSSI
 *
 * Contributors:
 * 2019 Thomas Letan <thomas.letan@ssi.gouv.fr>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *)

From FreeSpec Require Export Exec.
From Coq Require Export String.

Generalizable All Variables.

Inductive CONSOLE : interface :=
| Scan : CONSOLE string
| Echo (str : string) : CONSOLE unit.

Register CONSOLE as freespec.stdlib.console.type.
Register Scan as freespec.stdlib.console.Scan.
Register Echo as freespec.stdlib.console.Echo.

Definition scan `{Provide ix CONSOLE} : impure ix string :=
  request Scan.

Definition echo `{Provide ix CONSOLE} (str: string) : impure ix unit :=
  request (Echo str).

Declare ML Module "freespec_stdlib_console".
