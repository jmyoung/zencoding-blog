-- Delay 10 seconds on startup, then start executing code
function startup()
	print('executing script')
	dofile('dht_reader.lc')
end

-- 	NOTE - You have 10 seconds to delete this file or stop the timer with;
--		tmr.unregister(0)
--	Or your code will execute and you'll probably be unable to do anything!

print("in startup, 'tmr.unregister(0)' to abort")
tmr.alarm(0,10000,0,startup)