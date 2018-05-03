## Types
## =====
using ArgParse
using DSLearn
import DSLearn: isobservable, observe!, net
using DataStructures
using MLDatasets
import Base.Iterators
import IterTools
using TensorboardX

DSLearn.isobservable(::Any) = true

## Types
## =====
data(x) = x.data

"Learned representation of an Integer"
struct NInt{T} <: Integer
  data::T
end
NInt(x::Int) = convert(NInt, x)
Base.size(::Type{NInt}) = (3,)

"CInt continuous representation of an Integer"
struct CInt{T} <: Integer
  data::T
end
Base.size(::Type{CInt}) = (1,)

"Learned Bool"
struct NBool{T}
  data::T
end
Base.size(::Type{NBool}) = (1,)

struct CBool{T}
  data::T
end
Base.size(::Type{CBool}) = (1, )

## Conversions
## ===========
DSLearn.observe_type(::Type{<:NInt}) = CInt
DSLearn.observe_type(::Type{Int}) = CInt
DSLearn.observe_type(::Type{<:NBool}) = CBool
DSLearn.observe_type(::Type{Bool}) = CBool

Base.convert(T::Type{NInt}, x::CInt) = net(Base.convert, Type{NInt}, CInt)(x)
Base.convert(T::Type{NInt}, x::Int) = convert(NInt, convert(CInt, x))
Base.convert(T::Type{CInt}, x::NInt) = net(Base.convert, Type{CInt}, NInt)(x)

Base.convert(::Type{Bool}, x::NBool) = convert(Bool, convert(CBool, x))
Base.convert(::Type{CBool}, x::NBool) = net(Base.convert, Type{CBool}, NBool)(x)

## Interface
## =========
Base.:+(x::NInt, y::NInt) = net(+, NInt, NInt)(x, y)
Base.:+(x::NInt, y::Int) = x + convert(NInt, y) # FIXME DRY
Base.:-(x::NInt, y::NInt) = net(+, NInt, NInt)(x, y)
Base.:-(x::NInt, y::Int) = x - convert(NInt, y)
Base.:>(x::NInt, y::NInt) = net(>, NInt, NInt)(x, y)
Base.:>(x::NInt, y::Int) = x > convert(NInt, y)

## Programs
## ========
function ex1(rng, I::Type)
  x = observe!(:a, I(1) + I(2))
  z = observe!(:b, x + rand(rng, 1:10))
  if convert(Bool, observe!(:b1, z > 5))
    z = observe!(:c1, z + rand(rng, 1:10))
  else
    z = observe!(:c2, z - rand(rng, 1:10))
  end
  z
end

## Param
## =====

struct Param
end

## PyTorch specific
## ================
# using PyCall
# using PyTorch
# @pyimport asl

# function variable(x::Int, requires_grad=false)
#   x = fill(float(x), (1, 1))
#   Tensor(autograd.Variable(PyTorch.torch.Tensor(x), requires_grad=requires_grad))
# end
# PyCall.PyObject(x::NInt) = PyObject(x.data)
# PyCall.PyObject(x::NBool) = PyObject(x.data)
# PyCall.PyObject(x::CInt) = PyObject(x.data)

# Base.convert(::Type{CInt}, x::Int) = CInt(variable(x)) #FIXME1
# Base.convert(::Type{CBool}, x::Bool) = CBool(variable(Int(x)))
# Base.convert(::Type{Bool}, x::CBool) = x.data.data[:data][1,1] > 0.5

# # function load_nets!(p::Param)
#   nmids = 5
#   nint_cint_ = asl.MLPNet([size(CInt)], [size(NInt)], batch_norm=false, nmids=PyVector([nmids]))
#   nint_cint = NInt ∘ Tensor ∘ first ∘ nint_cint_
#   @inline DSLearn.net(::typeof(Base.convert), ::Type{Type{NInt}}, ::Type{CInt}) = nint_cint

#   cint_nint_ = asl.MLPNet([size(NInt)], [size(CInt)], batch_norm=false, nmids=PyVector([nmids]))
#   cint_nint = CInt  ∘ Tensor ∘ first ∘ cint_nint_
#   @inline DSLearn.net(::typeof(Base.convert), ::Type{Type{CInt}}, ::Type{NInt}) = cint_nint
  
#   cbool_nbool_ = asl.MLPNet([size(NBool)], [size(CBool)], batch_norm=false, nmids=PyVector([nmids]))
#   cbool_nbool = CBool ∘ Tensor ∘ functional.sigmoid ∘ first ∘ cbool_nbool_
#   @inline DSLearn.net(::typeof(Base.convert), ::Type{Type{CBool}}, ::Type{NBool}) = cbool_nbool
  
#   plus_net_ = asl.MLPNet([size(NInt), size(NInt)], [size(NInt)], batch_norm=false, nmids=PyVector([5]))
#   plus_net = NInt ∘ Tensor ∘ first  ∘ plus_net_
#   @inline DSLearn.net(::typeof(+), ::Type{NInt}, ::Type{NInt}) = plus_net

#   sub_net_ = asl.MLPNet([size(NInt), size(NInt)], [size(NInt)], batch_norm=false, nmids=PyVector([5]))
#   sub_net = NInt ∘ Tensor ∘ first  ∘ sub_net_
#   @inline DSLearn.net(::typeof(-), ::Type{NInt}, ::Type{NInt}) = sub_net

#   ngt_net_ = asl.MLPNet([size(NInt), size(NInt)], [size(NBool)], batch_norm=false, nmids=PyVector([5]))
#   ngt_net = NBool ∘ Tensor ∘ first ∘ ngt_net_
#   @inline DSLearn.net(::typeof(>), ::Type{NInt}, ::Type{NInt}) = ngt_net

# function load_nets!(p::Param)
#   ngt_net_, sub_net_, plus_net_, cint_nint_, nint_cint_, cbool_nbool_
# end

# function optimizer(fs, consts)
#   params = vcat((collect(f[:parameters]()) for f in fs)...)
#   allparams = [consts..., params...]
#   optim.Adam(allparams)
# end

# mse(x, y) = PyTorch.torch.norm(x.data - y.data)
# accum(losses) = PyTorch.torch.stack(losses)[:mean]()

## FLUX Specific 
## =============
import FluxAddons: mlp
using Flux
using Flux.Tracker

Base.convert(::Type{CInt}, x::Int) = CInt(param([x])) #FIXME1
Base.convert(::Type{CBool}, x::Bool) = CBool(param([x]))
Base.convert(::Type{Bool}, x::CBool) = x.data[1] > 0.5

nmids = 5
nint_cint = mlp(CInt, NInt, nmids=[5])
@inline net(::typeof(Base.convert), ::Type{Type{NInt}}, ::Type{CInt}) = nint_cint

cint_nint = mlp(NInt, CInt, nmids=[5])
@inline net(::typeof(Base.convert), ::Type{Type{CInt}}, ::Type{NInt}) = cint_nint

cbool_nbool = mlp(NBool, CBool, nmids=[5])
@inline net(::typeof(Base.convert), ::Type{Type{CBool}}, ::Type{NBool}) = cbool_nbool

plus_net = mlp((NInt, NInt), NInt, nmids=[5])
@inline net(::typeof(+), ::Type{NInt}, ::Type{NInt}) = plus_net

sub_net = mlp((NInt, NInt), NInt, nmids=[5])
@inline net(::typeof(-), ::Type{NInt}, ::Type{NInt}) = sub_net

ngt_net = mlp((NInt, NInt), NBool, nmids=[5])
@inline net(::typeof(>), ::Type{NInt}, ::Type{NInt}) = ngt_net

function load_nets!(p::Param)
  return [ngt_net, sub_net, plus_net, cint_nint, nint_cint, cbool_nbool]
end

mse(x::AbstractArray, y::AbstractArray) = Flux.mse(x, y)
accum(losses) = mean(losses)

function optimizer(fs, consts)
  fs
  consts
  allparams = vcat(params.(fs)..., params.(consts)...)
  Flux.Optimise.ADAM(allparams)
end

## Distances
## =========

δ(x::CInt, y::CInt) = mse(x.data, y.data)
δ(x::CBool, y::CBool) = mse(x.data, y.data)

## Training
## ========
writer = SummaryWriter()

function train_arithmetic(batch_size = 1)
  nrng = MersenneTwister(1234)
  refrng = MersenneTwister(1234)
  ref_tg() = trace(Any, () -> ex1(refrng, Int64))
  n_tg() = trace(Any, () -> ex1(nrng, NInt))
  ref_tg, n_tg
end

update!(opt::Function) = opt()
data(x::Flux.Tracker.TrackedReal) = x.tracker.data

"Generate steps"
function stepgen(ref_ds, n_ds, δ, optimizer; traceperstep=64)

  function step!(cb_data, callbacks)
    all_losses = []
    for i = 1:traceperstep
      net_trace = n_ds()
      ref_trace = ref_ds()
      losses = DSLearn.losses(net_trace, ref_trace, δ)
      for loss in losses
        push!(all_losses, loss)
      end
      # @show all_losses = vcat(all_losses, losses)
    end
    if cb_data[:i] % 100 == 0
      # @show all_losses
    end
    all_losses
    @show loss = accum(all_losses)
    add_scalar!(writer, "Loss", data(loss), cb_data[:i])
    back!(loss)
    update!(optimizer)
    loss
    # @assert false
  end
end

function train()
  p = Param()
  nets = load_nets!(p)
  ref_tg, n_tg = train_arithmetic()
  optimizer_ = optimizer(nets, [])
  step! = stepgen(ref_tg, n_tg, δ, optimizer_)
  # save_params!()
  DSLearn.Optim.optimize(step!)
end

train()