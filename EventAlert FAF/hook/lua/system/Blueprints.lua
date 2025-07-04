do
	local EXPvoiceTable = {
		{'uel0401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04179'}},
		{'ues0401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04180'}},
		{'ueb2401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04181'}},
		{'url0402', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04182'}},
		{'ura0401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04183'}},
		{'url0401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04184'}},
		{'ual0401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04185'}},
		{'uaa0310', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04186'}},
		{'uas0401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04187'}},
		{'xab1401', Sound {Bank = 'X06_VO', Cue = 'X06_HQ_M02_04491'}},
		{'xsl0401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04188'}},
		{'xsa0402', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04189'}},
		{'xsb2401', Sound {Bank = 'XGG', Cue = 'XGG_HQ_GD1_04190'}},
	}

    local OldModBlueprints = ModBlueprints
    function ModBlueprints(all_blueprints)
        OldModBlueprints(all_blueprints)
        for id,bp in all_blueprints.Unit do
		    if table.find(bp.Categories, 'EXPERIMENTAL') and bp.Audio then
			    for k, v in EXPvoiceTable do
				    if bp.BlueprintId == v[1] then
					    bp.Audio['ExperimentalDetected'] = v[2]
					end
				end
            end
        end
    end
	
end

