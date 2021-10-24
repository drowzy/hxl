defmodule Terraform do
  def decode!(tf) do
    HXL.decode!(tf, evaluator: Terraform.Evaluator)
  end
end

