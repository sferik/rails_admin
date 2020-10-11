if CI_ORM == :mongoid
  filename =
    if Mongoid.respond_to?(:belongs_to_required_by_default=)
      'mongoid6.yml'
    else
      'mongoid5.yml'
    end
  ::Mongoid.load!(Rails.root.join('config', filename))
end
