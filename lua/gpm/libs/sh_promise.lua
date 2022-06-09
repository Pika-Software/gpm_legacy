--- A Lua implementation of Promise/A+
module( "GPM", package.seeall )

--[[
	- Promise documentation

	List of promise functions:
		promise:getState() -- Returns state of promise (pending, fulfilled or rejected)
		promise:isPending()
		promise:isFulfilled()
		promise:isRejected()

		promise:getResult() -- Returns result of Promise if not pending (fulfilled value or reason why rejected)

		promise:callback([resolve, reject]) -- Adds callback for Promise. (resolve for fulfillment, reject for rejectment)
		                                       resolve and reject must be functions (but they are optional).
		                                       Same as `then` function in Promise/A+ specification
		                                       See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/then
		promise:try(resolve) -- Same as :callback, but only takes resolve function
		promise:catch(reject) -- Same as :callback, but only takes reject function

		promise:await() -- Waits promise response, 
		                   and returns value when fullfilled, 
		                   or throws error when rejected
		                   NB! Works only in async functions! See GPM.Promise.async

		-- You can use functions below, but you shouldn't
		promise:resolve( value ) -- Fulfills promise with given value (see https://promisesaplus.com/#the-promise-resolution-procedure)
		promise:reject( value ) -- Rejects promise with given value
	
	Global functions:
		GPM.async( func ) -- Wraps function, and returns async function
		GPM.await( promise ) -- Same as promise:await()

		GPM.Promise( func ) -- Creates a promise, runs function with `resolve` and `reject` callbacks and returns the promise. See examples below

		GPM.Promise.hasCallback( obj )
		GPM.Promise.isPromise( obj )
		GPM.Promise.isAwaitable( obj )

		GPM.Promise.async( func ) -- Same as GPM.async( func )
		GPM.Promise.await( promise ) -- Same as promise:await()

		GPM.Promise.resolve( value ) -- Returns a promise, that fulfilled with given value
		GPM.Promise.reject( reason ) -- Returns a promise, that rejected with given reason

		GPM.Promise.delay( time_in_seconds ) -- Returns a promise, that will resolve after given time in seconds.
		GPM.Promise.all( promises ) -- Returns a promise, that will return an array of results of promises in given array of promises. See examples below
		GPM.Promise.race( promises ) -- Returns a promise, that will return first result of given promises

	Examples:
		Example of async http function
		```
			function HTTPRequest(url, headers)
				return GPM.Promise(function(resolve, reject)
					local onSuccess = function(body, size, headers, code)
						resolve({
							body = body,
							size = size,
							headers = headers,
							code = code,
						})
					end

					local onFailure = function(reason)
						reject(reason)
					end

					http.Fetch(url, onSuccess, onFailure, headers)
				end)
			end

			HTTPRequest("https://google.com"):try(function(data)
				PrintTable(data) 
					-- body = "..."
					-- size = 12345
					-- headers = { ... }
					-- code = 200
			end)
		```

		Example of using HTTPRequest in async function
		```
			local async_func = GPM.async(function(url)
				local data = HTTPRequest( url ):await()

				print(data.code) -- 200, 404 or etc.
				return data.code
			end)

			-- Running our async function
			local p = async_func("https://google.com")

			print(p) -- Promise 0x012345678 {<pending>}

			p:try(function(code) print(code) end) -- 200
		```

		Example of parsing http request in json
		```
			function JSONRequest(url, headers)
				return HTTPRequest(url, headers):try(function(data)
					return util.JSONToTable( data.body )
				end)
			end

			JSONRequest("https://httpbin.org/get"):try(function(data)
				PrintTable(data)
					-- headers = { ... }
					-- args = {}
					-- origin = "xxx.xxx.xxx.xxx"
					-- url = "https://httpbin.org/get"
			end)
		```

		This promise library is similar to Javascript promises,
		only differences is `.then` changed to `:callback` (`:try` is an alias to `:callback` without onReject callback),
		and there is no `.finally` function.

		Also that is missing, are Promise.allSettled and Promise.any, because i don't want to make it, and maybe will make them in future
--]]
local promise = CreateClass( "Promise" )

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

function promise:_resolve_queue()
	local fullfillFallback = function(value)
		return value
	end

	local rejectFallback = function(reason)
		error(reason)
	end

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
		local ok, result = pcall(function()
			return handler( self:getResult() )
		end)

		if ok then
			-- Running resolve with result, that handler gived to us
			queuedPromise:resolve( result )
		else
			-- Remove error from default handler
			if result then
				result = string.gsub(result, "addons/gpm/lua/gpm/libs/sh_promise.lua:[^%s]+ ", "")
			end

			queuedPromise:_reject(result)
		end
	end
end

function promise:_process()
	if self._processing then return end
	if self:isPending() then return end

	self._processing = true
	NextTick(function()
		self._processing = false

		self:_resolve_queue()
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

---
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

---
function promise:reject(value)
	-- yes, this is _reject alias
	self:_reject(value)
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
	local obj = InheritClass( promise )

	obj.state = "pending"
	obj._queue = {}
	obj._processing = false
	obj._onFulfillHandler = nil 
	obj._onRejectHandler = nil

	-- Running function, if it is given
	if isfunction(func) then
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
			p:resolve( result )
		else
			p:reject( result )
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
			callCount = callCount + 1
			
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

-- And just aliases

async = Promise.async
await = Promise.await
