defmodule HXL.LexerTest do
  use ExUnit.Case

  test "can lex output containing carriage return + newline" do
    for hcl <- ["\ra=1\r", "\r\na=1\r\n", "\r\na=1\r\n"] do
      assert {:ok, out, <<>>, _ctx, _, _} = HXL.Lexer.tokenize(hcl)
      assert length(out) > 0
    end
  end
end
