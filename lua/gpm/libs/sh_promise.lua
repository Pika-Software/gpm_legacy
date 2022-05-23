--- A Lua implementation of Promise/A+
module( "GPM", package.seeall )

local promise = {}
promise.__index = promise

function promise:getState()
	return self.state or "pending"
end

function promise:isPending()
	return self:getState() == "pending"
end

function promise:isFulfilled()
	return self:getState() == "fulfilled"
end

function promise:isRejected()
	return self:getState() == "rejected"
end

function promise:getResult()
	return self.result
end

function promise:__tostring()
	if self:isPending() then return ("Promise %p {<pending>}"):format(self) end

	return ("Promise %p {<%s>: %s}"):format(self, self:getState(), ValueToString( self:getResult() ))
end

function promise:_process()
	if self._processing then return end
	if self:isPending() then return end

	local fullfillFallback = function(value)
		return value
	end

	local rejectFallback = function(reason)
		error(reason)
	end

	self._processing = true
	NextTick(function()
		self._processing = false

		if #self._queue == 0 and self:isRejected() then
			ErrorNoHalt("Unhandled promise error: ", self:getResult(), "\n\n")
			return
		end

		-- while queue is not empty
		while #self._queue > 0 do
			local queuedPromise = table.remove(self._queue, 1)
	
			local handler
			if self:isFulfilled() then
				handler = queuedPromise._onFulfillHandler or fullfillFallback
			elseif self:isRejected() then
				handler = queuedPromise._onRejectHandler or rejectFallback
			end
	
			local result
			local ok = xpcall(function()
				result = handler( self:getResult() )
			end, function(err)
				-- Remove error from default handler
				err = string.gsub(err, "addons/gpm/lua/gpm/libs/sh_promise.lua:[^%s]+ ", "")

				queuedPromise:_reject(err)
			end)

			if ok then
				-- Running resolve with result, that handler gived to us
				queuedPromise:resolve( result )
			end

		end
	end)
end

function promise:_transition(state, value)
	if self.state == state then return end
	if not self:isPending() then return end
	--if not self:isPending() then error("Promise cannot change it state more than once.") end
	if state != "pending" and state != "fulfilled" and state != "rejected" then error("Trying to set invalid state: " .. state) end

	self.result = value
	self.state = state
	self:_process()
end

function promise:_fulfill(value)
	self:_transition("fulfilled", value)
end

function promise:_reject(reason)
	self:_transition("rejected", reason)
end

function promise:resolve(value)
	if promise == value then

		self:_reject("The promise and its value refer to the same object")

	elseif Promise.hasCallback(value) then
		if Promise.isPromise(value) and not value:isPending() then
			-- if promise given and it is not pending, then just copy it state and result
			self:_transition( value:getState(), value:getResult() )

		else

			local called = false
			local ok, err = pcall(function()
				-- Waiting for thenable object result
				value:callback(function(result)
					-- Resolve
					if not called then
						self:resolve(result)
					end
				end, function(err)
					-- Reject
					if not called then
						self:_reject(err)
					end
				end)

			end)
	
			-- If something went wrong, reject
			if not ok and not called then
				self:_reject(err)
				called = true
			end

		end

	else

		self:_fulfill(value)

	end
end

function promise:callback(onFulfilled, onRejected)
	local queuedPromise = self.new()

	if isfunction(onFulfilled) then
		queuedPromise._onFulfillHandler = onFulfilled
	end

	if isfunction(onRejected) then
		queuedPromise._onRejectHandler = onRejected
	end

	table.insert(self._queue, queuedPromise)
	self:_process()

	return queuedPromise
end

function promise:try(onFulfilled)
	return self:callback(onFulfilled)
end

function promise:catch(onRejected)
	return self:callback(nil, onRejected)
end

--- Await for async functions
-- @see Promise.async
function promise:await()
	local co = coroutine.running()
	if not co then error("Await works only in async functions!") end

	self:callback(function(result)
		coroutine.resume(co, true, result)
	end, function(err)
		coroutine.resume(co, false, err)
	end)

	local ok, result = coroutine.yield()

	if not ok then
		error( result )
	end

	return result
end

function promise.new(func)
	local obj = setmetatable({}, promise)

	obj.state = "pending"
	obj._queue = {}
	obj._processing = false
	obj._onFulfillHandler = nil 
	obj._onRejectHandler = nil

	-- Running function, if it is given
	if func then
		local resolve = function(value)
			obj:resolve(value)
		end
	
		local reject = function(reason)
			obj:_reject(reason)
		end

		func(resolve, reject)
	end

	return obj
end

Promise = setmetatable({}, { __call = function(self, ...) return promise.new(...) end })

--- Helper for identifying a promise-like objects
function Promise.hasCallback(obj)
	return istable(obj) and isfunction(obj.callback)
end

--- Helper for identifying a promise
function Promise.isPromise(obj)
	return istable(obj) and getmetatable(obj) == promise
end

--- Helper for identifying an awaitable object
function Promise.isAwaitable(obj)
	return istable(obj) and isfunction(obj.await)
end

--- Creates async function
function Promise.async(func)
	CheckType( func, 1, "function", 3 )

	local function run(p, ...)
		local ok, result = pcall(func, ...)

		if ok then
			p:_fulfill( result )
		else
			p:_reject( result )
		end
	end

	return function(...)
		local p = Promise()

		local co = coroutine.create(run)
		coroutine.resume(co, p, ...)

		return p
	end
end

--- Await shortcut
-- equal to :await()
-- @see promise:await
function Promise.await(p)
	if not Promise.isAwaitable(p) then error("expected awaitable object.") end
	
	return p:await()
end

--- Async wait function
-- @param time in secods
-- @return a promise
function Promise.delay(time)
	return Promise(function(resolve) timer.Simple(time, resolve) end)
end

--- Returns a promise fulfilled with given value
function Promise.resolve(value)
	if Promise.isPromise(value) then return value end

	return Promise(function(resolve) resolve(value) end)
end

--- Returns a promise rejected with given error
function Promise.reject(err)
	return Promise(function(resolve, reject) reject(err) end)
end

--- 
-- @param array of promises
-- @return promise that returns an array of promise results
function Promise.all(promises)
	local new_promise = Promise()
	local results = {}
	local callCount = 0
	local lenght = #promises

	local onFulfill = function(i)
		return function(result)
			if not new_promise:isPending() then return end

			results[i] = result
			callCount = 1
			
			if callCount == lenght then
				new_promise:resolve( results )
			end
		end
	end

	local onReject = function(err)
		if not new_promise:isPending() then return end

		new_promise:_reject(err)
	end

	for i, p in ipairs(promises) do
		p = Promise.resolve( p )
		p:callback( onFulfill(i), onReject )
	end

	return new_promise
end

---
function Promise.race(promises)
	local new_promise = Promise()

	local onFulfill = function(result)
		if not new_promise:isPending() then return end

		new_promise:resolve(result)
	end

	local onReject = function(err)
		if not new_promise:isPending() then return end

		new_promise:_reject(err)
	end

	for _, p in ipairs(promises) do
		p = Promise.resolve( p )
		p:callback( onFulfill, onReject )
	end

	return new_promise
end