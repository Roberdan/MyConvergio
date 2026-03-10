//! T1-09: Mesh peer authentication via HMAC-SHA256 challenge-response.
//! Pre-shared key loaded from peers.conf `[mesh]` section `shared_secret=...`

use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::path::Path;

type HmacSha256 = Hmac<Sha256>;
const NONCE_LEN: usize = 32;

/// Generate a random 32-byte nonce for the challenge
pub fn generate_nonce() -> Vec<u8> {
    let mut nonce = vec![0u8; NONCE_LEN];
    rand::fill(&mut nonce[..]);
    nonce
}

/// Compute HMAC-SHA256(secret, nonce) for challenge-response
pub fn compute_hmac(secret: &[u8], nonce: &[u8]) -> Vec<u8> {
    let mut mac = HmacSha256::new_from_slice(secret).expect("HMAC key");
    mac.update(nonce);
    mac.finalize().into_bytes().to_vec()
}

/// Verify a peer's HMAC response against expected
pub fn verify_hmac(secret: &[u8], nonce: &[u8], response: &[u8]) -> bool {
    let mut mac = HmacSha256::new_from_slice(secret).expect("HMAC key");
    mac.update(nonce);
    mac.verify_slice(response).is_ok()
}

/// Load shared secret from peers.conf `[mesh]` section
pub fn load_shared_secret(peers_conf: &Path) -> Option<Vec<u8>> {
    let content = std::fs::read_to_string(peers_conf).ok()?;
    let mut in_mesh_section = false;
    for line in content.lines().map(str::trim) {
        if line.eq_ignore_ascii_case("[mesh]") {
            in_mesh_section = true;
            continue;
        }
        if line.starts_with('[') {
            in_mesh_section = false;
            continue;
        }
        if in_mesh_section {
            if let Some((key, value)) = line.split_once('=') {
                if key.trim() == "shared_secret" {
                    let secret = value.trim();
                    if !secret.is_empty() {
                        return Some(secret.as_bytes().to_vec());
                    }
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hmac_roundtrip_succeeds() {
        let secret = b"test-shared-secret-123";
        let nonce = generate_nonce();
        let hmac = compute_hmac(secret, &nonce);
        assert!(verify_hmac(secret, &nonce, &hmac));
    }

    #[test]
    fn hmac_rejects_wrong_secret() {
        let nonce = generate_nonce();
        let hmac = compute_hmac(b"correct-secret", &nonce);
        assert!(!verify_hmac(b"wrong-secret", &nonce, &hmac));
    }

    #[test]
    fn hmac_rejects_wrong_nonce() {
        let secret = b"shared-key";
        let nonce1 = generate_nonce();
        let nonce2 = generate_nonce();
        let hmac = compute_hmac(secret, &nonce1);
        assert!(!verify_hmac(secret, &nonce2, &hmac));
    }

    #[test]
    fn loads_secret_from_peers_conf() {
        let tmp = std::env::temp_dir().join("test_peers_auth.conf");
        std::fs::write(&tmp, "[mesh]\nshared_secret = my-secret-key-42\n\n[peer1]\ntailscale_ip=100.1.2.3\n").unwrap();
        let secret = load_shared_secret(&tmp);
        assert_eq!(secret.as_deref(), Some(b"my-secret-key-42".as_slice()));
        let _ = std::fs::remove_file(&tmp);
    }

    #[test]
    fn returns_none_without_mesh_section() {
        let tmp = std::env::temp_dir().join("test_peers_no_mesh.conf");
        std::fs::write(&tmp, "[peer1]\ntailscale_ip=100.1.2.3\n").unwrap();
        assert!(load_shared_secret(&tmp).is_none());
        let _ = std::fs::remove_file(&tmp);
    }

    #[test]
    fn returns_none_for_empty_secret() {
        let tmp = std::env::temp_dir().join("test_peers_empty_secret.conf");
        std::fs::write(&tmp, "[mesh]\nshared_secret = \n").unwrap();
        assert!(load_shared_secret(&tmp).is_none());
        let _ = std::fs::remove_file(&tmp);
    }

    #[test]
    fn returns_none_for_missing_file() {
        let path = Path::new("/tmp/nonexistent_peers_99887766.conf");
        assert!(load_shared_secret(path).is_none());
    }

    #[test]
    fn nonce_uniqueness() {
        let n1 = generate_nonce();
        let n2 = generate_nonce();
        assert_ne!(n1, n2, "two nonces should not be equal");
        assert_eq!(n1.len(), NONCE_LEN);
    }

    #[test]
    fn hmac_rejects_empty_response() {
        let secret = b"secret";
        let nonce = generate_nonce();
        assert!(!verify_hmac(secret, &nonce, &[]));
    }

    #[test]
    fn hmac_rejects_truncated_response() {
        let secret = b"secret";
        let nonce = generate_nonce();
        let hmac = compute_hmac(secret, &nonce);
        assert!(!verify_hmac(secret, &nonce, &hmac[..16]));
    }
}
