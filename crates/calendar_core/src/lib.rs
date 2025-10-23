//! Calendar Core - Rust business logic for calendar operations
//!
//! This crate provides core calendar functionality including:
//! - ICS (iCalendar) export/import
//! - Recurrence rule processing
//! - Timezone handling

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

pub mod ics_export;

// Re-export main types for convenience
pub use ics_export::{export_ics_json, EventDto, ExportRequest, IcsError};

/// FFI function to export events to ICS format
///
/// # Safety
/// The caller must:
/// - Pass a valid null-terminated UTF-8 JSON string
/// - Call `ics_export_free_string` on the returned pointer when done
/// - Not use the pointer after freeing it
///
/// # Returns
/// On success: pointer to null-terminated ICS string
/// On error: null pointer (caller should check for null)
#[no_mangle]
pub extern "C" fn ics_export_ffi(json_req: *const c_char) -> *mut c_char {
    // Safety: Validate the input pointer
    if json_req.is_null() {
        eprintln!("ics_export_ffi: Received null pointer");
        return std::ptr::null_mut();
    }

    // Convert C string to Rust string
    let json_str = unsafe {
        match CStr::from_ptr(json_req).to_str() {
            Ok(s) => s,
            Err(e) => {
                eprintln!("ics_export_ffi: Invalid UTF-8 in input: {}", e);
                return std::ptr::null_mut();
            }
        }
    };

    // Call the export function
    match export_ics_json(json_str) {
        Ok(ics_content) => {
            // Convert result to C string
            match CString::new(ics_content) {
                Ok(c_string) => c_string.into_raw(),
                Err(e) => {
                    eprintln!("ics_export_ffi: Failed to create C string: {}", e);
                    std::ptr::null_mut()
                }
            }
        }
        Err(e) => {
            eprintln!("ics_export_ffi: Export failed: {}", e);
            std::ptr::null_mut()
        }
    }
}

/// Free a string allocated by ics_export_ffi
///
/// # Safety
/// The caller must:
/// - Only call this on pointers returned by ics_export_ffi
/// - Only call this once per pointer
/// - Not use the pointer after calling this
#[no_mangle]
pub extern "C" fn ics_export_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        // Reconstruct and drop the CString to free memory
        let _ = CString::from_raw(ptr);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_export() {
        let json = r#"{
            "prod_id": "-//Test//Calendar 1.0//EN",
            "cal_name": "Test",
            "events": []
        }"#;

        let result = export_ics_json(json);
        assert!(result.is_ok());
        assert!(result.unwrap().contains("BEGIN:VCALENDAR"));
    }
}
