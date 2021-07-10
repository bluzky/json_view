# JsonView

**Render json easier with relationship and custom data rendering**

## Installation

The package can be installed
by adding `json_view` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:json_view, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/json_view](https://hexdocs.pm/json_view).


## How to use it

  Normally, you query data from database then render to JSON and return to client, and you might want to:

  - Keep the original value
  - Return value in a new format, or return some calculated data
  - Render relationships that defined by Ecto schema

  JsonView helps to render json data easier by support relationship and custom render data.
  Most of the time you may want to add it to your view:

```elixir
  def view do
    quote do
      ...
      use JsonView
      ...
    end
  end
```

  Or you can use it directly on your view

```elixir
  defmodule MyApp.PostView do
      use JsonView

      # define which fields return without modifying
      @fields [:title, :content, :excerpt, :cover]
      # define which fields that need to format or calculate, you have to define `render_field/2` below
      @custom_fields [:like_count]
      # define which view used to render relationship
      @relationships [author: MyApp.AuthorView]

      def render("post.json", %{post: post}) do
          # 1st way if `use JsonView`
          render_json(post, @fields, @custom_fields, @relationships)
      end

      def render_field(:like_count, item) do
          # load like_count from some where
      end
  end
```

**How to define fields and relationships**
- **Custom field**

  ```elixir
  @custom_fields [:like_count]
  # this invokes `render(:like_count, post)`
  
  @custom_fields [like_count: &my_function/1]
  # this invokes `my_function.(post)`
  ```

- **Relationship**

  ```elixir
  @relationships [author: MyApp.UserView]
  # this invokes `MyApp.UserView.render("user.json", %{user: user})`
  
  @relationships [author: {MyApp.UserView, "basic_profile.json"}]
  # this invokes `MyApp.UserView.render("basic_profile.json", %{user: user})`
  ```

**Data override**

  `JsonView` render `fields` -> `custom_fields` -> `relationships`. If they define same field, then the latter will override the prior


**Default fields**

  You can pass a list of default `fields` and/or `custom_fields` as options to `use JsonView`. These fields then merged to `fields` and `custom_fields` before rendering data each time you invoke `render_json`

```elixir
  use JsonView, fields: [:id, :updated_at], custom_fields: [inserted_at: &to_local_time/2]
```

**Render hook**

  You can pass a function to process data after `JsonView` completes rendering like this:

```elixir
  use JsonView, after_render: &convert_all_datetime_to_local/1

  def convert_all_datetime_to_local(data) do
    Enum.map(data, fn {k, v} ->
      v =
        case v do
          %NaiveDateTime{} -> to_local_datetime(v)
          _ -> v
        end
      {k, v}
    end)
    |> Enum.into(%{})
  end
```
