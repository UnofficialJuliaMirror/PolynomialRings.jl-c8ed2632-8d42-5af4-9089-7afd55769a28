module Backends

module Gröbner
    struct Buchberger end
    default = Buchberger()
    set_default()  = (global default; default=Buchberger())
    set_default(x) = (global default; default=x)
end

end
