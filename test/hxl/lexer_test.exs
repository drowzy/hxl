defmodule HXL.LexerTest do
  use ExUnit.Case

  test "can lex output containing carriage return + newline" do
    for hcl <- ["\ra=1\r", "\r\na=1\r\n", "\r\na=1\r\n"] do
      assert {:ok, out, <<>>, _ctx, _, _} = HXL.Lexer.tokenize(hcl)
      assert length(out) > 0
    end
  end

  test "can lex output containing tabs + spaces" do
    for hcl <- ["\ta=1\s", "\t\sa=1\t\s"] do
      assert {:ok, out, <<>>, _ctx, _, _} = HXL.Lexer.tokenize(hcl)
      assert length(out) > 0
    end
  end

  test "can lex template directives into parts" do
    hcl = ~s("text before ${interpolation} after")

    {:ok, out, _, _, _, _} = HXL.Lexer.tokenize(hcl)

    assert [
             {:string_part, ["text before "]},
             {:"${", []},
             {:identifier, ["interpolation"]},
             {:"}", []},
             {:string_part, [" after"]}
           ] == Enum.map(out, &token_value_pair/1)
  end

  test "can lex string interpolation into parts" do
    hcl = ~s("text before ${interpolation} after")

    {:ok, out, _, _, _, _} = HXL.Lexer.tokenize(hcl)

    assert [
             {:string_part, ["text before "]},
             {:"${", []},
             {:identifier, ["interpolation"]},
             {:"}", []},
             {:string_part, [" after"]}
           ] == Enum.map(out, &token_value_pair/1)
  end

  test "can lex directives into parts" do
    hcl = ~s|"%{if true} truthy %{else} falsy %{endif}"|

    {:ok, out, _, _, _, _} = HXL.Lexer.tokenize(hcl)

    assert [
             {:"%{", []},
             {:if, []},
             {true, []},
             {:"}", []},
             {:string_part, [" truthy "]},
             {:"%{", []},
             {:else, []},
             {:"}", []},
             {:string_part, [" falsy "]},
             {:"%{", []},
             {:endif, []},
             {:"}", []}
           ] == Enum.map(out, &token_value_pair/1)
  end

  defp token_value_pair({token, _, value}), do: {token, value}
  defp token_value_pair({token, _}), do: {token, []}
end
