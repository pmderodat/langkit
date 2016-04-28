## vim: filetype=makoada

--  Start tok_code

## Get the current token
${res} := ${pos_name};

declare
   T : constant Token_Raw_Data_Type := Get_Token (Parser.TDH.all, ${res});
   K : constant Token_Kind := Token_Kind'Enum_Val (T.Id);
begin
   if K /= ${token_kind} then
       ## If the result is not the one we expect, set pos to error
       ${pos} := -1;

       ## Document this failure so we can have a diagnostic at the end of
       ## parsing.
       if Parser.Last_Fail.Pos <= ${pos_name} then
           Parser.Last_Fail.Pos := ${pos_name};
           Parser.Last_Fail.Expected_Token_Id := ${token_kind};
           Parser.Last_Fail.Found_Token_Id := K;
       end if;
   else
      ## We don't want to increment the position if we are matching the
      ## termination token (eg. the last token in the token stream).
      % if token_kind == get_context().lexer.ada_token_name('termination'):
          ${pos} := ${pos_name};
      ## Else increment the current position
      % else:
          ${pos} := ${pos_name} + 1;
      % endif
   end if;
end;

--  End tok_code
