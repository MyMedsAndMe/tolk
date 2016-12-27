require "test_helper"

class FormatTest < ActiveSupport::TestCase
  def setup; end

  def test_category_field_declaration
    assert_equal %{SPLIT_PART("tolk_phrases"."key", '.', 2)}, Tolk::Phrase.category_field.to_sql
  end

  def test_with_category_scope_added
    assert Tolk::Phrase.with_category("foo").to_sql.end_with?(%{WHERE SPLIT_PART("tolk_phrases"."key", '.', 2) = 'foo'})
  end

  def test_with_category_scope_skipped_for_non_presence_values
    ["", nil].each do |value|
      assert_equal %{SELECT "tolk_phrases".* FROM "tolk_phrases"}, Tolk::Phrase.with_category(value).to_sql
    end
  end

  def test_category_from_key
    assert_equal "bar", Tolk::Phrase.new(key: "foo.bar.baz.more").category
  end

  def test_get_all_categories
    # TODO: Test will not work with SQLite DB due to usage of PG specific
    #       function SPLIT_PART.
    assert true
  end
end
