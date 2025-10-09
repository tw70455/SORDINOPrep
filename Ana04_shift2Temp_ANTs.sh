# Set the path where the anatomical files are located
# Set the subject IDs you want to process

set FILE_PATH="/Volumes/ProcessDisk/fMRIData/"
set NUMS="Subj01 Subj02 Subj03"


# Set base directory (where the script is located)
set BASE_DIR = `dirname $0`

# Template related files
set TEMPLATE_IMG  = "${BASE_DIR}/Template/ZTE_Template_mean_Ants_resample_allineate_resample.nii.gz"
set TEMPLATE_REF  = "${BASE_DIR}/Template/ZTE_Template_mean_Ants_resample_allineate_2ZTE.nii.gz" 
set TEMPLATE_MASK = "${BASE_DIR}/Template/ZTE_Template_mean_Ants_resample_allineate_resample_mask.nii.gz"                           # 


set OMP_NUM_THREADS = 4

foreach ratNum(${NUMS}) # 
	if  ( -e "${FILE_PATH}${ratNum}_Func.nii.gz" ) then



		# create masked anatomical image
		rm -f "${FILE_PATH}${ratNum}_Anat_masked.nii.gz"
	    3dcalc \
	      -a "${FILE_PATH}${ratNum}_Anat.nii.gz" \
	      -b "${FILE_PATH}${ratNum}_Anat_mask.nii.gz" \
	      -expr 'a*ispositive(b)' \
	      -prefix "${FILE_PATH}${ratNum}_Anat_masked.nii.gz"


		# bias correction
		rm -f "${FILE_PATH}${ratNum}_Anat_masked_unify5.nii.gz"
		3dUnifize -Urad 5 \
		  -prefix "${FILE_PATH}${ratNum}_Anat_masked_unify5.nii.gz" \
		  "${FILE_PATH}${ratNum}_Anat_masked.nii.gz"



	    # initial normalization
	    rm -f "${FILE_PATH}${ratNum}_Anat_affineOnly_*"
	    antsRegistrationSyN.sh \
	      -d 3 \
	      -f "${TEMPLATE_IMG}" \
	      -m "${FILE_PATH}${ratNum}_Anat_masked_unify5.nii.gz" \
	      -o "${FILE_PATH}${ratNum}_Anat_affineOnly_" \
	      -t a \
	      -n ${OMP_NUM_THREADS}
		  
		  
		# inverse template mask to native space
		rm -f "${FILE_PATH}${ratNum}_TemplateMask_inSubj_AffineOnly.nii.gz"
	    antsApplyTransforms \
	      -d 3 --float 1 \
	      -i "${TEMPLATE_MASK}" \
	      -r "${FILE_PATH}${ratNum}_Anat_masked_unify5.nii.gz" \
	      -o "${FILE_PATH}${ratNum}_TemplateMask_inSubj_AffineOnly.nii.gz" \
	      -t "[${FILE_PATH}${ratNum}_Anat_affineOnly_0GenericAffine.mat,1]" \
	      -n NearestNeighbor



		# remask the anatomical image
		rm -f "${FILE_PATH}${ratNum}_Anat_Masked.nii.gz"
	    3dcalc \
	      -a "${FILE_PATH}${ratNum}_Anat.nii.gz" \
	      -b "${FILE_PATH}${ratNum}_TemplateMask_inSubj_AffineOnly.nii.gz" \
	      -expr 'a*step(b)' \
	      -prefix "${FILE_PATH}${ratNum}_Anat_Masked.nii.gz"

		# bias-correction
		rm -f "${FILE_PATH}${ratNum}_Anat_Masked_unify5.nii.gz"
	    3dUnifize -Urad 5 \
	      -prefix "${FILE_PATH}${ratNum}_Anat_masked_unify5.nii.gz" \
	      "${FILE_PATH}${ratNum}_Anat_Masked.nii.gz"


		
		# Register anatomical to template using ANTs
		antsRegistrationSyN.sh -d 3 -f "${BASE_DIR}/Template/ZTE_Template_mean_Ants_resample_allineate_resample.nii.gz" \
		-m "${FILE_PATH}${ratNum}_Anat_masked_unify5.nii.gz" \
			-o "${FILE_PATH}${ratNum}_Anat_masked_unify5_Ants" -t s -n 4


		# Remove previous warped functional file if it exists
		rm "${FILE_PATH}${ratNum}_Func_ANTsWarped.nii.gz"
		# Apply the anatomical-derived transforms to the functional image
		antsApplyTransforms -d 3 -e 3 -v 1 --float \
		  -i "${FILE_PATH}${ratNum}_Func.nii.gz" \
		  -r "${BASE_DIR}/Template/ZTE_Template_mean_Ants_resample_allineate_2ZTE.nii.gz" \
		  -o "${FILE_PATH}${ratNum}_Func_ANTsWarped.nii.gz" \
		  -t "${FILE_PATH}${ratNum}_Anat_masked_unify5_Ants1Warp.nii.gz" \
		  -t "${FILE_PATH}${ratNum}_Anat_masked_unify5_Ants0GenericAffine.mat" \
		  -n Linear

		

	else
		echo "Warning! ${FILE_PATH}${ratNum}_Func.nii.gz not found."
	endif
end



