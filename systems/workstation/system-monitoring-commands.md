# Quick daily health check

echo "SMU errors today: $(journalctl --since today | grep -i 'SMU uninitialized' | wc -l)"
echo "Suspends today: $(journalctl --since today | grep -E 'Suspending|suspend entered' | wc -l)"
