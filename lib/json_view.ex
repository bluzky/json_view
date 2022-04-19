defmodule JsonView do
  @moduledoc """
  Normally, you query data from database then render to JSON and return to client, and you might want to:

  - Keep the original value
  - Return value in a new format, or return some calculated data
  - Render relationships that defined by Ecto schema

  JsonView helps to render json data easier by support relationship and custom render data.
  Most of the time you may want to add it to your view:

      def view do
        quote do
          ...
          use JsonView
          ...
        end
      end

  Or you can use it directly on your view

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

  **How to define fields and relationships**
  - **Custom field**

        @custom_fields [:like_count]
        # this invokes `render(:like_count, post)`

        @custom_fields [like_count: &my_function/1]
        # this invokes `my_function.(post)`

  - **Relationship**

        @relationships [author: MyApp.UserView]
        # this invokes `MyApp.UserView.render("user.json", %{user: user})`

        @relationships [author: {MyApp.UserView, "basic_profile.json"}]
        # this invokes `MyApp.UserView.render("basic_profile.json", %{user: user})`

  **Data override**
  `JsonView` render `fields` -> `custom_fields` -> `relationships`. If they define same field, then the latter will override the prior


  **Default fields**
  You can pass a list of default `fields` and/or `custom_fields` as options to `use JsonView`. These fields then merged to `fields` and `custom_fields` before rendering data each time you invoke `render_json`

      use JsonView, fields: [:id, :updated_at], custom_fields: [inserted_at: &to_local_time/2]

  **Render hook**
  You can pass a function to process data after `JsonView` completes rendering like this:

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
  """

  defmacro __using__(opts \\ []) do
    fields = Keyword.get(opts, :fields, [])
    custom_fields = Keyword.get(opts, :custom_fields, [])

    after_render = Keyword.get(opts, :after_render)

    quote do
      def render_json(struct, fields, custom_fields \\ [], relationships \\ []) do
        data =
          JsonView.render_json(struct, __MODULE__,
            fields: unquote(fields) ++ fields,
            custom_fields: unquote(custom_fields) ++ custom_fields,
            relationships: relationships
          )

        if is_function(unquote(after_render)) do
          apply(unquote(after_render), [data])
        else
          data
        end
      end

      def render_view(struct, view, template \\ nil) do
        JsonView.render_template(struct, view, template)
      end
    end
  end

  @doc """
  Render a struct to a map with given options

  - `fields`: which fields are extract directly from struct
  - `custom_fields`: which fields are render using custom `render_field/2` function
  - `relationships`: a list of {field, view_module} defines which fields are rendered using another view
  """

  def render_json(nil, _, _), do: nil

  def render_json(struct, view, opts) when is_list(opts) do
    fields = Keyword.get(opts, :fields, [])
    custom_fields = Keyword.get(opts, :custom_fields, [])
    relationships = Keyword.get(opts, :relationships, [])

    struct
    |> render_fields(fields)
    |> Map.merge(render_custom_fields(struct, view, custom_fields))
    |> Map.merge(render_relationships(struct, relationships))
  end

  @doc """
  Simply take the value from struct by list of keys without modifying the values
  """
  def render_fields(structs, fields) do
    Map.take(structs, fields)
  end

  @doc """
  Render field with custom render function
  View module must defines `render_field/2` function to render each custom field

      use JsonView

      def render_field(:is_success, item) do
        item.state > 3
      end

      # then this invoke above function
      render_custom_fields(struct, __MODULE__, [:is_success])

  """

  def render_custom_fields(struct, view \\ nil, fields) do
    # if fields is not empty and render_field/2 is not defined, raise exception

    fields
    |> Enum.map(fn
      {field, render_func} when is_function(render_func) ->
        {field, render_func.(struct)}

      field ->
        {field, view.render_field(field, struct)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Render relationship field for struct. `relationships` is a list of {field, view} for mapping render.
  For each field, call function `View.render()` to render json for relation object.

  Example relationships:

      relationships = [comments: CommentView, author: UserView]
      # or use a custom template instead of default template "user.json" in this case
      relationships = [comments: CommentView, author: {UserView, "basic_info.json}]

  Result of `render_relationships(post, relationships)` equal to output of below code

      %{
          comments: CommentView.render_many(comments, CommentView, "comment.json"),
          author: UserView.render_one(author, UserView, "user.json")
      }
  """
  def render_relationships(struct, relationships) when is_list(relationships) do
    Enum.map(relationships, fn {field, view} ->
      {field, render_relationship(struct, field, view)}
    end)
    |> Enum.into(%{})
  end

  def render_relationship(struct, field, {view, template}) do
    references = Map.get(struct, field)
    render_template(references, view, template)
  end

  def render_relationship(struct, field, view) do
    references = Map.get(struct, field)

    render_template(references, view)
  end

  @doc """
  Decide how to render the resource depend on type of resource
  """
  def render_template(resource, view, template \\ nil) do
    template = template || "#{get_resource_name(view)}.json"

    case resource do
      %{__struct__: struct} when struct == Ecto.Association.NotLoaded ->
        nil

      %{} ->
        render_one(resource, view, template)

      resource when is_list(resource) ->
        render_many(resource, view, template)

      _ ->
        nil
    end
  end

  @doc """
  Render one item if not nil, similar to `Phoenix.View.render_one/3`
  It invokes the function `render(template, %{model_name: data})` in the view module

  **Example**

    render_one(user, MyApp.UserView, "user.json")
    # then invoke
    MyApp.UserView.render("user.json", %{user: user})
  """
  def render_one(resource, view, template) do
    resource_name = get_resource_name(view)
    view.render(template, Map.put(%{}, resource_name, resource))
  end

  @doc """
  Render list of item, similar to `Phoenix.View.render_many/3`
  """
  def render_many(data, view, template) when is_list(data) do
    Enum.map(data, &render_one(&1, view, template))
  end

  # get relationship name. Ex: HeraWeb.ProductView -> product
  # this value is used to map assign when render relationship
  # render_one(product, HeraWeb.ProductView, "product.json")
  defp get_resource_name(view) do
    view
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> to_string()
    |> String.trim_trailing("_view")
    |> String.to_existing_atom()
  end
end
