require 'spec_helper'

describe 'Defining many-to-one association' do
  include_context 'users and tasks'

  before do
    configuration.relation(:users) { use :assoc_macros }
  end

  it 'extends relation with association methods' do
    configuration.relation(:tasks) do
      use :assoc_macros

      many_to_one :users, key: :user_id, on: { name: 'Jane' }

      def all
        select(:id, :title)
      end

      def with_user
        association_join(:users, select: [:name])
      end
    end

    configuration.mappers do
      define(:tasks)

      define(:with_user, parent: :tasks) do
        wrap :user do
          attribute :name
        end
      end
    end

    tasks = container.relations.tasks

    expect(tasks.all.with_user.to_a).to eql(
      [{ id: 2, name: 'Jane', title: "Jane's task" }]
    )

    expect(container.relation(:tasks).map_with(:with_user).all.with_user.to_a).to eql(
      [{ id: 2, title: "Jane's task", user: { name: 'Jane' } }]
    )
  end

  it "joins on specified key" do
    configuration.relation(:task_tags) do
      use :assoc_macros

      many_to_one :tags, key: :tag_id

      def with_tags
        association_left_join(:tags)
      end
    end

    configuration.relation(:tags) { use :assoc_macros }

    expect(container.relation(:task_tags).with_tags.to_a).to eq(
      [{ tag_id: 1, task_id: 1, id: 1, name: "important" }]
    )
  end
end
