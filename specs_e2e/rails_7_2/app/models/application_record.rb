class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # primary_replica points at the primary database: the transactional_server
  # smoke test reads through it to check that reading roles see the rows the
  # server has not committed.
  connects_to database: { writing: :primary, reading: :primary_replica } if Rails.env.test?
end
