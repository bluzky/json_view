defmodule Ecto.Association.NotLoaded do
  @moduledoc """
  This is fake struct
  """
  defstruct [:id]
end

defmodule JsonViewTest do
  use ExUnit.Case

  use JsonView

  @data %{
    name: "John Doe",
    age: 20,
    email: "test@gmail.com",
    address: %{
      ward: "Ben Nghe",
      district: "1",
      city: "HCM"
    }
  }

  test "render field" do
    assert %{
             name: "John Doe",
             age: 20,
             email: "test@gmail.com"
           } = render_json(@data, [:name, :age, :email], [], [])
  end

  test "render field not exist should not return" do
    assert %{
             name: "John Doe",
             age: 20,
             email: "test@gmail.com"
           } == render_json(@data, [:name, :age, :email, :class], [], [])
  end

  test "render custom field" do
    assert %{
             name: "John Doe",
             is_teenager: false
           } = render_json(@data, [:name], [:is_teenager], [])
  end

  test "render custom field with no match function should raise error" do
    assert_raise FunctionClauseError, fn -> render_json(@data, [:name], [:is_hero], []) end
  end

  test "render relationship should success" do
    assert %{
             address: %{
               ward: "Ben Nghe",
               district: "1",
               city: "HCM"
             }
           } = render_json(@data, [], [], address: Test.AddressView)
  end

  test "render relationship with custom template should success" do
    full_address = "#{@data.address.ward}, #{@data.address.district}, #{@data.address.city}"

    assert %{
             address: %{
               full_address: ^full_address
             }
           } = render_json(@data, [], [], address: {Test.AddressView, "custom_address.json"})
  end

  test "render relationship with nil should return nil" do
    assert %{address: nil} =
             @data
             |> Map.put(:address, nil)
             |> render_json([], [], address: Test.AddressView)
  end

  test "render relationship with not loaded association should return nil" do
    assert %{address: nil} =
             @data
             |> Map.put(:address, %Ecto.Association.NotLoaded{})
             |> render_json([], [], address: Test.AddressView)
  end

  test "render list relationship should success" do
    data =
      @data
      |> Map.put(:addresses, [
        %{
          ward: "Ben Nghe",
          district: "1",
          city: "HCM"
        },
        %{
          ward: "Ben Nghe2",
          district: "2",
          city: "HCM2"
        }
      ])

    assert %{
             addresses: [
               %{
                 ward: "Ben Nghe",
                 district: "1",
                 city: "HCM"
               },
               %{
                 ward: "Ben Nghe2",
                 district: "2",
                 city: "HCM2"
               }
             ]
           } = render_json(data, [], [], addresses: Test.AddressView)
  end

  def render_field(:is_teenager, data) do
    data.age < 20
  end
end

defmodule Test.AddressView do
  use JsonView

  def render("address.json", %{address: address}) do
    render_json(address, [:ward, :district, :city], [], [])
  end

  def render("custom_address.json", %{address: address}) do
    render_json(address, [], [full_address: &render_full_address/1], [])
  end

  def render_full_address(address) do
    "#{address.ward}, #{address.district}, #{address.city}"
  end
end
