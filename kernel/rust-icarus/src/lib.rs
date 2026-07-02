// SPDX-License-Identifier: GPL-2.0
//! Minimal Icarus Rust kernel module.

#![no_std]
#![feature(allocator_api, global_asm)]

use kernel::prelude::*;
use kernel::procfs;

module! {
    type: IcarusModule,
    name: "icarus_rust",
    author: "Icarus OS",
    description: "Rust kernel module for Icarus",
    license: "GPL",
}

struct IcarusModule;

impl kernel::Module for IcarusModule {
    fn init(_name: &'static CStr, _module: &'static ThisModule) -> Result<Self> {
        pr_info!("Icarus Rust module loaded.\n");
        procfs::create_entry(b"icarus", 0, None, |_file, _buffer| {
            "The wolf is awake.\n"
        })?;
        Ok(IcarusModule)
    }
}

impl Drop for IcarusModule {
    fn drop(&mut self) {
        pr_info!("Icarus Rust module unloaded.\n");
        procfs::remove_entry(b"icarus");
    }
}
