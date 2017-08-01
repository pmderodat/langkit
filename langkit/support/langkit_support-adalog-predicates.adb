with Langkit_Support.Adalog.Debug; use Langkit_Support.Adalog.Debug;

package body Langkit_Support.Adalog.Predicates is

   ---------------
   -- Predicate --
   ---------------

   package body Predicate is

      ----------
      -- Free --
      ----------

      procedure Free (Self : in out Predicate_Logic) is
      begin
         Remove_Predicate (Self.Ref, Self'Unrestricted_Access);
         Free (Self.Pred);
      end Free;

      -----------
      -- Apply --
      -----------

      overriding function Apply
        (Self : in out Predicate_Logic) return Solving_State
      is
      begin
         if not Is_Defined (Self.Ref) then
            Trace ("In Predicate apply, var " & Image (Self.Ref)
                   & " not defined, no progress");
            return No_Progress;
         end if;

         Trace ("In Predicate apply, calling predicate");
         declare
            R : constant Boolean := Call (Self.Pred, Get_Value (Self.Ref));
         begin
            Trace (R'Img);
            return +R;
         end;
      end Apply;

      ------------
      -- Revert --
      ------------

      procedure Revert (Self : in out Predicate_Logic) is
      begin
         Remove_Predicate (Self.Ref, Self'Unchecked_Access);
      end Revert;

   end Predicate;

   -----------------
   -- N_Predicate --
   -----------------

   package body N_Predicate is

      ----------
      -- Free --
      ----------

      procedure Free (Self : in out Predicate_Logic) is
      begin
         for Ref of Self.Refs loop
            Remove_Predicate (Ref, Self'Unrestricted_Access);
         end loop;
         Free (Self.Pred);
      end Free;

      -----------
      -- Apply --
      -----------

      overriding function Apply
        (Self : in out Predicate_Logic) return Solving_State
      is
      begin
         for Ref of Self.Refs loop
            if not Is_Defined (Ref) then
               Trace ("In N_Predicate apply, var " & Image (Ref)
                      & " not defined, deferring application");
               return No_Progress;
            end if;
         end loop;

         Trace ("In N_Predicate apply, calling predicate");
         declare
            Vals : Val_Array (1 .. Arity);
         begin
            for I in Self.Refs'Range loop
               Vals (I) := Get_Value (Self.Refs (I));
            end loop;

            return +Call (Self.Pred, Vals);
         end;
      end Apply;

      ------------
      -- Revert --
      ------------

      procedure Revert (Self : in out Predicate_Logic) is
      begin
         for Ref of Self.Refs loop
            Remove_Predicate (Ref, Self'Unchecked_Access);
         end loop;
      end Revert;

   end N_Predicate;

   package body Predicate_2 is

      ----------
      -- Free --
      ----------

      procedure Free (Self : in out Predicate_Wrapper) is
      begin
         Free (Self.T);
      end Free;

      ------------
      -- Create --
      ------------

      function Create
        (L, R : Var.Var; Pred : Predicate_Type) return Relation
      is
      begin
         return Predicate_2_Internal.Create
           ((L, R), Predicate_Wrapper'(Pred, L, R));
      end Create;

   end Predicate_2;

end Langkit_Support.Adalog.Predicates;
