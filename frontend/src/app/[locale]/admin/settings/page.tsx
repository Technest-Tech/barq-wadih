'use client';

import { useState, useEffect } from 'react';
import {
  fetchSettings, updateSetting, bulkUpdateSettings,
  type SettingGroup,
} from '@/lib/api/admin-settings';
import styles from './settings.module.css';

const GROUP_LABELS: Record<string, { icon: string; label: string }> = {
  commission: { icon: '💰', label: 'إعدادات العمولة' },
  ads:        { icon: '📢', label: 'إعدادات الإعلانات' },
  boost:      { icon: '🚀', label: 'إعدادات التعزيز' },
  general:    { icon: '⚙️', label: 'إعدادات عامة' },
};

export default function AdminSettingsPage() {
  const [groups, setGroups] = useState<SettingGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [openGroups, setOpenGroups] = useState<Set<string>>(new Set());
  const [editedValues, setEditedValues] = useState<Record<string, string>>({});
  const [savedKeys, setSavedKeys] = useState<Set<string>>(new Set());
  const [savingAll, setSavingAll] = useState(false);

  useEffect(() => {
    fetchSettings()
      .then(data => {
        setGroups(data);
        // Open all groups by default
        setOpenGroups(new Set(data.map(g => g.group)));
      })
      .finally(() => setLoading(false));
  }, []);

  const toggleGroup = (group: string) => {
    setOpenGroups(prev => {
      const next = new Set(prev);
      if (next.has(group)) next.delete(group); else next.add(group);
      return next;
    });
  };

  const handleValueChange = (key: string, value: string) => {
    setEditedValues(prev => ({ ...prev, [key]: value }));
  };

  const handleSaveSingle = async (key: string) => {
    const value = editedValues[key];
    if (value === undefined) return;
    try {
      await updateSetting(key, value);
      setSavedKeys(prev => new Set(prev).add(key));
      setTimeout(() => setSavedKeys(prev => { const next = new Set(prev); next.delete(key); return next; }), 2000);
      // Update the group data
      setGroups(prev => prev.map(g => ({
        ...g,
        settings: g.settings.map(s => s.key === key ? { ...s, value } : s),
      })));
      setEditedValues(prev => { const next = { ...prev }; delete next[key]; return next; });
    } catch { alert('فشل حفظ الإعداد'); }
  };

  const handleBulkSave = async () => {
    const entries = Object.entries(editedValues);
    if (entries.length === 0) return;
    setSavingAll(true);
    try {
      await bulkUpdateSettings(entries.map(([key, value]) => ({ key, value })));
      // Update local state
      setGroups(prev => prev.map(g => ({
        ...g,
        settings: g.settings.map(s => editedValues[s.key] !== undefined ? { ...s, value: editedValues[s.key] } : s),
      })));
      setEditedValues({});
      alert(`تم حفظ ${entries.length} إعدادات`);
    } catch { alert('فشل الحفظ'); } finally { setSavingAll(false); }
  };

  const handleToggle = async (key: string, currentValue: string) => {
    const newValue = currentValue === '1' || currentValue === 'true' ? '0' : '1';
    try {
      await updateSetting(key, newValue);
      setGroups(prev => prev.map(g => ({
        ...g,
        settings: g.settings.map(s => s.key === key ? { ...s, value: newValue } : s),
      })));
      setSavedKeys(prev => new Set(prev).add(key));
      setTimeout(() => setSavedKeys(prev => { const next = new Set(prev); next.delete(key); return next; }), 2000);
    } catch { alert('فشل تغيير الإعداد'); }
  };

  if (loading) {
    return <div className={styles.loading}><div className={styles.loadingSpinner} /><span>جاري تحميل الإعدادات...</span></div>;
  }

  const hasChanges = Object.keys(editedValues).length > 0;

  return (
    <div className={styles.page}>
      <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9', marginBottom: '1.5rem' }}>
        ⚙️ إعدادات النظام
      </h1>

      {groups.map(group => {
        const meta = GROUP_LABELS[group.group] || { icon: '📋', label: group.group };
        const isOpen = openGroups.has(group.group);

        return (
          <div key={group.group} className={styles.groupSection}>
            <div className={styles.groupHeader} onClick={() => toggleGroup(group.group)}>
              <span className={styles.groupTitle}>{meta.icon} {meta.label} ({group.settings.length})</span>
              <span className={`${styles.groupToggle} ${isOpen ? styles.groupToggleOpen : ''}`}>▶</span>
            </div>

            {isOpen && (
              <div className={styles.groupBody}>
                {group.settings.map(setting => {
                  const isBoolean = setting.type === 'boolean';
                  const currentValue = editedValues[setting.key] ?? setting.value;
                  const isTruthy = currentValue === '1' || currentValue === 'true';
                  const isEdited = editedValues[setting.key] !== undefined;
                  const isSaved = savedKeys.has(setting.key);

                  return (
                    <div key={setting.key} className={styles.settingRow}>
                      <div>
                        <div className={styles.settingKey}>{setting.key}</div>
                        {setting.description && <div className={styles.settingDesc}>{setting.description}</div>}
                      </div>
                      <div className={styles.settingValue}>
                        <span className={styles.typeBadge}>{setting.type_label}</span>

                        {isBoolean ? (
                          <button
                            className={`${styles.settingToggle} ${isTruthy ? styles.settingToggleOn : styles.settingToggleOff}`}
                            onClick={() => handleToggle(setting.key, currentValue)}
                          />
                        ) : (
                          <input
                            className={styles.settingInput}
                            type={setting.type === 'integer' || setting.type === 'decimal' ? 'number' : 'text'}
                            step={setting.type === 'decimal' ? '0.001' : undefined}
                            value={currentValue}
                            onChange={e => handleValueChange(setting.key, e.target.value)}
                            dir={setting.type === 'json' ? 'ltr' : undefined}
                          />
                        )}

                        {!isBoolean && isEdited && (
                          <button className={styles.saveBtn} onClick={() => handleSaveSingle(setting.key)}>حفظ</button>
                        )}

                        {isSaved && <span className={styles.savedIndicator}>✓ تم</span>}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}

      {hasChanges && (
        <div className={styles.bulkActions}>
          <button className={styles.bulkBtn} disabled={savingAll} onClick={handleBulkSave}>
            {savingAll ? 'جاري الحفظ...' : `💾 حفظ الكل (${Object.keys(editedValues).length})`}
          </button>
        </div>
      )}
    </div>
  );
}
