class Symbol
  def ivar
    "@#{self}".to_sym
  end

  def plural_ivar
    "@#{self}s".to_sym
  end

  def plural_fn
    "#{self}s".to_sym
  end
end
