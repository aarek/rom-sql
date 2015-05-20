require 'spec_helper'
require 'anima'

describe 'Commands / Update' do
  include_context 'database setup'

  subject(:users) { rom.command(:users) }

  let(:relation) { rom.relations.users }
  let(:piotr) { relation.by_name('Piotr').first }
  let(:peter) { { name: 'Peter' } }

  before do
    setup.relation(:users) do
      def by_id(id)
        where(id: id).limit(1)
      end

      def by_name(name)
        where(name: name)
      end
    end

    setup.commands(:users) do
      define(:update)
    end

    User = Class.new { include Anima.new(:id, :name) }

    setup.mappers do
      register :users, entity: -> tuples { tuples.map { |tuple| User.new(tuple) } }
    end

    relation.insert(name: 'Piotr')
  end

  after { Object.send(:remove_const, :User) }

  context '#transaction' do
    it 'update record if there was no errors' do
      result = users.update.transaction do
        users.update.by_id(piotr[:id]).call(peter)
      end

      expect(result.value).to eq([{ id: 1, name: 'Peter' }])
    end

    it 'updates nothing if error was raised' do
      users.update.transaction do
        users.update.by_id(piotr[:id]).call(peter)
        raise ROM::SQL::Rollback
      end

      expect(relation.first[:name]).to eq('Piotr')
    end
  end

  it 'updates everything when there is no original tuple' do
    result = users.try do
      users.update.by_id(piotr[:id]).call(peter)
    end

    expect(result.value.to_a).to match_array([{ id: 1, name: 'Peter' }])
  end

  it 'updates when attributes changed' do
    result = users.try do
      users.as(:entity).update.by_id(piotr[:id]).change(User.new(piotr)).call(peter)
    end

    expect(result.value.to_a).to match_array([User.new(id: 1, name: 'Peter')])
  end

  it 'does not update when attributes did not change' do
    piotr_rel = double('piotr_rel').as_null_object

    expect(relation).to receive(:by_id).with(piotr[:id]).and_return(piotr_rel)
    expect(piotr_rel).not_to receive(:update)

    result = users.try do
      users.update.by_id(piotr[:id]).change(piotr).to(name: piotr[:name])
    end

    expect(result.value.to_a).to be_empty
  end

  it 'handles database errors' do
    expect {
      users.try { users.update.by_id(piotr[:id]).call(bogus_field: '#trollface') }
    }.to raise_error(ROM::SQL::DatabaseError, /UndefinedColumn/)
  end
end
