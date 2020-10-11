# coding: utf-8

class Team < ActiveRecord::Base
  has_many :players, -> { order :id }, inverse_of: :team
  has_and_belongs_to_many :fans
  has_many :comments, as: :commentable

  validates_numericality_of :division_id, only_integer: true
  validates_presence_of :manager
  validates_numericality_of :founded, only_integer: true, allow_blank: true
  validates_numericality_of :wins, only_integer: true
  validates_numericality_of :losses, only_integer: true
  validates_numericality_of :win_percentage
  validates_numericality_of :revenue, allow_nil: true
  belongs_to :division, optional: true

  enum main_sponsor: %i[no_sponsor food_factory transportation_company bank energy_producer]

  def player_names_truncated
    players.collect(&:name).join(', ')[0..32]
  end

  def color_enum
    ['white', 'black', 'red', 'green', 'blu<e>é']
  end

  scope :green, -> { where(color: 'red') }
  scope :red, -> { where(color: 'red') }
  scope :white, -> { where(color: 'white') }
end
