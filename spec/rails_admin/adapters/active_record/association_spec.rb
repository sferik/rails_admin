require 'spec_helper'
require 'timecop'

RSpec.describe 'RailsAdmin::Adapters::ActiveRecord::Association', active_record: true do
  before :all do
    RailsAdmin::AbstractModel.reset_polymorphic_parents

    class ARBlog < Tableless
      has_many :a_r_posts
      has_many :a_r_comments, as: :commentable
      belongs_to :librarian, polymorphic: true
    end

    class ARPost < Tableless
      belongs_to :a_r_blog
      has_and_belongs_to_many :a_r_categories
      has_many :a_r_comments, as: :commentable
    end

    class ARCategory < Tableless
      has_and_belongs_to_many :a_r_posts
      belongs_to :librarian, polymorphic: true
    end

    class ARUser < Tableless
      has_one :a_r_profile
      has_many :a_r_categories, as: :librarian
    end

    class ARProfile < Tableless
      belongs_to :a_r_user
      has_many :a_r_blogs, as: :librarian
    end

    class ARComment < Tableless
      belongs_to :commentable, polymorphic: true
    end

    @blog = RailsAdmin::AbstractModel.new(ARBlog)
    @post = RailsAdmin::AbstractModel.new(ARPost)
    @category = RailsAdmin::AbstractModel.new(ARCategory)
    @user = RailsAdmin::AbstractModel.new(ARUser)
    @profile = RailsAdmin::AbstractModel.new(ARProfile)
    @comment = RailsAdmin::AbstractModel.new(ARComment)
  end

  after :all do
    RailsAdmin::AbstractModel.reset_polymorphic_parents
  end

  it 'lists associations' do
    what_to_include = %w(a_r_blog a_r_categories a_r_comments)
    expect(@post.associations.collect { |a| a.name.to_s }).to include(*what_to_include)
  end

  it 'list associations types in supported [:belongs_to, :has_and_belongs_to_many, :has_many, :has_one]' do
    # ActiveRecord 4.1 converts has_and_belongs_to_many association to has_many
    what_to_include = %w(belongs_to has_many has_one)
    expect((@post.associations + @blog.associations + @user.associations).collect(&:type).uniq.collect(&:to_s)).to include(*what_to_include)
  end

  describe 'belongs_to association' do
    subject { @post.associations.detect { |a| a.name == :a_r_blog } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'A r blog'
      expect(subject.type).to eq :belongs_to
      expect(subject.klass).to eq ARBlog
      expect(subject.primary_key).to eq :id
      expect(subject.foreign_key).to eq :a_r_blog_id
      expect(subject.foreign_type).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end
  end

  describe 'has_many association' do
    subject { @blog.associations.detect { |a| a.name == :a_r_posts } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'A r posts'
      expect(subject.type).to eq :has_many
      expect(subject.klass).to eq ARPost
      expect(subject.primary_key).to eq :id
      expect(subject.foreign_key).to eq :ar_blog_id
      expect(subject.foreign_type).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end
  end

  describe 'has_many association' do
    let(:league) { RailsAdmin::AbstractModel.new(League) }

    context 'for direct has many' do
      let(:association) { league.associations.detect { |a| a.name == :divisions } }

      it 'returns correct values' do
        expect(association.type).to eq :has_many
        expect(association.klass).to eq Division
        expect(association.read_only?).to be_falsey
        expect(association.foreign_key_nullable?).to be_truthy
      end
    end

    context 'for has many through marked as readonly' do
      let(:association) { league.associations.detect { |a| a.name == :teams } }

      it 'returns correct values' do
        expect(association.type).to eq :has_many
        expect(association.klass).to eq Team
        expect(association.read_only?).to be_truthy
        expect(association.foreign_key_nullable?).to be_truthy
      end
    end

    context 'for has many through multiple associations' do
      let(:association) { league.associations.detect { |a| a.name == :players } }

      it 'returns correct values' do
        expect(association.type).to eq :has_many
        expect(association.klass).to eq Player
        expect(association.read_only?).to be_truthy
      end
    end
  end

  describe 'has_many association with not nullable foreign key' do
    let(:field_test) { RailsAdmin::AbstractModel.new(FieldTest) }
    let(:association) { field_test.associations.detect { |a| a.name == :nested_field_tests } }

    context 'for direct has many' do
      it 'returns correct values' do
        expect(association.foreign_key_nullable?).to be_falsey
      end
    end

    context 'when foreign_key is passed as Symbol' do
      before do
        class FieldTestWithSymbolForeignKey < FieldTest
          has_many :nested_field_tests, dependent: :destroy, inverse_of: :field_test, foreign_key: :field_test_id
        end
      end
      let(:field_test) { RailsAdmin::AbstractModel.new(FieldTestWithSymbolForeignKey) }

      it 'does not break' do
        expect(association.foreign_key_nullable?).to be_falsey
      end
    end
  end

  describe 'has_and_belongs_to_many association' do
    subject { @post.associations.detect { |a| a.name == :a_r_categories } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'A r categories'
      expect(subject.klass).to eq ARCategory
      expect(subject.primary_key).to eq :id
      expect(subject.foreign_type).to be_nil
      expect(subject.foreign_key_nullable?).to be_truthy
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end
  end

  describe 'polymorphic belongs_to association' do
    before { allow(RailsAdmin::Config).to receive(:models_pool).and_return(%w(ARBlog ARPost ARCategory ARUser ARProfile ARComment)) }
    subject { @comment.associations.detect { |a| a.name == :commentable } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Commentable'
      expect(subject.type).to eq :belongs_to
      expect(subject.klass).to eq [ARBlog, ARPost]
      expect(subject.primary_key).to be_nil
      expect(subject.foreign_key).to eq :commentable_id
      expect(subject.foreign_type).to eq :commentable_type
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_truthy
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end

    it 'looks up correct inverse model' do
      expect(@category.associations.detect { |a| a.name == :librarian }.klass).to eq [ARUser]
      expect(@blog.associations.detect { |a| a.name == :librarian }.klass).to eq [ARProfile]
    end
  end

  describe 'polymorphic inverse has_many association' do
    subject { @blog.associations.detect { |a| a.name == :a_r_comments } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'A r comments'
      expect(subject.type).to eq :has_many
      expect(subject.klass).to eq ARComment
      expect(subject.primary_key).to eq :id
      expect(subject.foreign_key).to eq :commentable_id
      expect(subject.foreign_type).to be_nil
      expect(subject.as).to eq :commentable
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end
  end
end
