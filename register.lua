-- ============================================================= --
-- EMPTY BALERS MOD
-- ============================================================= --
EmptyBalersREGISTER = {};

g_specializationManager:addSpecialization('bulkFill', 'BulkFill', Utils.getFilename('BulkFill.lua', g_currentModDirectory), true);

for name, data in pairs( g_vehicleTypeManager:getVehicleTypes() ) do
	local vehicleType = g_vehicleTypeManager:getVehicleTypeByName(tostring(name));
	if  SpecializationUtil.hasSpecialization(FillUnit, data.specializations) and
		SpecializationUtil.hasSpecialization(FillVolume, data.specializations) and
		SpecializationUtil.hasSpecialization(Cover, data.specializations)
	then
		g_vehicleTypeManager:addSpecialization(name, 'bulkFill')
	end
end
