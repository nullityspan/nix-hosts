"""Pseudonymise DICOM files with a keyed, deterministic mapping.

Same key + same PatientID -> same pseudonym, date shift and UIDs, so a
patient's studies stay linked over time after pseudonymisation.
"""

import argparse
import hashlib
import hmac
import os
import sys
import uuid
from datetime import datetime, timedelta
from pathlib import Path

import pydicom
from pydicom.errors import InvalidDicomError
from pydicom.multival import MultiValue

DEFAULT_KEY_FILE = "/run/secrets/pseudonym-key"
MAX_SHIFT_DAYS = 730
STANDARD_UID_ROOT = "1.2.840.10008."

# Identifying attributes dropped outright (subset of PS3.15 Annex E basic
# profile). Clinically useful ones (sex, age, size, weight) are kept.
REMOVE = {
    "AccessionNumber",
    "AdditionalPatientHistory",
    "BranchOfService",
    "CountryOfResidence",
    "CurrentPatientLocation",
    "DeviceSerialNumber",
    "EthnicGroup",
    "ImageComments",
    "InstitutionAddress",
    "InstitutionCodeSequence",
    "InstitutionName",
    "InstitutionalDepartmentName",
    "IssuerOfPatientID",
    "MedicalRecordLocator",
    "MilitaryRank",
    "NameOfPhysiciansReadingStudy",
    "Occupation",
    "OperatorsName",
    "OtherPatientIDs",
    "OtherPatientIDsSequence",
    "OtherPatientNames",
    "PatientAddress",
    "PatientBirthName",
    "PatientBirthTime",
    "PatientComments",
    "PatientInstitutionResidence",
    "PatientInsurancePlanCodeSequence",
    "PatientMotherBirthName",
    "PatientTelephoneNumbers",
    "PerformedLocation",
    "PerformingPhysicianName",
    "PhysiciansOfRecord",
    "ReferringPhysicianAddress",
    "ReferringPhysicianIdentificationSequence",
    "ReferringPhysicianName",
    "ReferringPhysicianTelephoneNumbers",
    "RegionOfResidence",
    "RequestAttributesSequence",
    "RequestingPhysician",
    "ResponsibleOrganization",
    "ResponsiblePerson",
    "ScheduledPerformingPhysicianName",
    "StationName",
    "StudyComments",
}


def load_key(path):
    key = Path(path).read_bytes().strip()
    if len(key) < 32:
        sys.exit(f"key in {path} too short (need >= 32 bytes)")
    return key


def digest(key, patient_id):
    return hmac.new(key, patient_id.encode(), hashlib.sha256).hexdigest()


def pseudonym(key, patient_id):
    return "PSN-" + digest(key, patient_id)[:16].upper()


def day_shift(key, patient_id):
    return -(int(digest(key, patient_id)[16:24], 16) % MAX_SHIFT_DAYS + 1)


def shift_da(value, days):
    try:
        d = datetime.strptime(value[:8], "%Y%m%d")
    except ValueError:
        return ""
    return (d + timedelta(days=days)).strftime("%Y%m%d")


def shift_dt(value, days):
    if len(value) < 8:
        return ""
    shifted = shift_da(value[:8], days)
    return shifted + value[8:] if shifted else ""


def map_values(value, fn):
    if isinstance(value, MultiValue):
        return [fn(str(v)) for v in value]
    return fn(str(value))


def remap_uid(key, uid):
    uid = str(uid)
    if not uid or uid.startswith(STANDARD_UID_ROOT):
        return uid
    mac = hmac.new(key, b"uid:" + uid.encode(), hashlib.sha256).digest()
    return f"2.25.{uuid.UUID(bytes=mac[:16], version=4).int}"


def pseudonymise(ds, key):
    patient_id = str(ds.get("PatientID", "")).strip()
    if not patient_id:
        raise ValueError("no PatientID")
    pid = pseudonym(key, patient_id)
    days = day_shift(key, patient_id)

    ds.remove_private_tags()

    def visit(dataset, elem):
        if elem.keyword in REMOVE:
            del dataset[elem.tag]
        elif elem.value in (None, ""):
            return
        elif elem.VR == "DA":
            elem.value = map_values(elem.value, lambda v: shift_da(v, days))
        elif elem.VR == "DT":
            elem.value = map_values(elem.value, lambda v: shift_dt(v, days))
        elif elem.VR == "UI":
            elem.value = map_values(elem.value, lambda v: remap_uid(key, v))

    ds.walk(visit)

    if "MediaStorageSOPInstanceUID" in ds.file_meta:
        ds.file_meta.MediaStorageSOPInstanceUID = ds.SOPInstanceUID

    ds.PatientID = pid
    ds.PatientName = pid
    ds.StudyID = pid[-8:]
    ds.PatientIdentityRemoved = "YES"
    ds.LongitudinalTemporalInformationModified = "MODIFIED"
    ds.DeidentificationMethod = "HMAC-SHA256 pseudonym, per-patient date shift, UID remap"
    return pid


def run(args):
    key = load_key(args.key_file)
    out = Path(args.output)
    files = [p for src in args.input for p in iter_files(Path(src))]
    done = skipped = 0
    for path in files:
        try:
            ds = pydicom.dcmread(path)
        except InvalidDicomError:
            continue
        if str(ds.get("BurnedInAnnotation", "")).upper() == "YES" and not args.allow_burned_in:
            print(f"skip (burned-in annotation): {path}", file=sys.stderr)
            skipped += 1
            continue
        try:
            pid = pseudonymise(ds, key)
        except ValueError as e:
            print(f"skip ({e}): {path}", file=sys.stderr)
            skipped += 1
            continue
        dest = out / pid / ds.StudyInstanceUID / ds.SeriesInstanceUID / f"{ds.SOPInstanceUID}.dcm"
        dest.parent.mkdir(parents=True, exist_ok=True)
        ds.save_as(dest, enforce_file_format=True)
        done += 1
    print(f"{done} written, {skipped} skipped -> {out}")


def lookup(args):
    key = load_key(args.key_file)
    for patient_id in args.patient_id:
        print(f"{patient_id}\t{pseudonym(key, patient_id)}\t{day_shift(key, patient_id)}d")


def iter_files(path):
    if path.is_file():
        yield path
    else:
        yield from (p for p in sorted(path.rglob("*")) if p.is_file())


def main():
    parser = argparse.ArgumentParser(prog="dicom-pseudonymise", description=__doc__)
    parser.add_argument(
        "--key-file",
        default=os.environ.get("PSEUDONYM_KEY_FILE", DEFAULT_KEY_FILE),
    )
    sub = parser.add_subparsers(required=True)

    p_run = sub.add_parser("run", help="pseudonymise files/directories into OUTPUT")
    p_run.add_argument("input", nargs="+")
    p_run.add_argument("-o", "--output", required=True)
    p_run.add_argument("--allow-burned-in", action="store_true")
    p_run.set_defaults(fn=run)

    p_id = sub.add_parser("id", help="show pseudonym and date shift for PatientIDs")
    p_id.add_argument("patient_id", nargs="+")
    p_id.set_defaults(fn=lookup)

    args = parser.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
